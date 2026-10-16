import Foundation
import Security
import Testing

@testable import Minutes

@Test func oauthCallbackRejectsMismatchedAndDuplicateState() throws {
  let valid = URL(
    string: "http://127.0.0.1:1234/auth/callback?state=expected&code=abc&client_id=oaiapp_test")!
  let (code, client) = try ChatGPTProtocol.callback(valid, state: "expected", clientID: nil)
  #expect(code == "abc")
  #expect(client == "oaiapp_test")
  #expect(throws: ChatGPTError.self) {
    try ChatGPTProtocol.callback(valid, state: "wrong", clientID: nil)
  }
  #expect(throws: ChatGPTError.self) {
    try ChatGPTProtocol.callback(valid, state: "expected", clientID: "other")
  }
  for query in [
    "state=expected&state=expected&code=a&client_id=b", "state=expected&error=access_denied",
    "state=expected&code=a&client_id=dynamic_agent_client", "state=expected&code=a",
  ] {
    #expect(throws: ChatGPTError.self) {
      try ChatGPTProtocol.callback(
        URL(string: "http://127.0.0.1/auth/callback?\(query)")!, state: "expected", clientID: nil)
    }
  }
}

@Test func summaryStreamRequiresSuccessfulCompletion() throws {
  var stream = SummaryStream()
  try stream.consume(Data(#"{"type":"response.output_text.delta","delta":"A decision."}"#.utf8))
  #expect(throws: ChatGPTError.self) { try stream.result() }
  try stream.consume(Data(#"{"type":"response.completed","response":{"status":"completed"}}"#.utf8))
  #expect(try stream.result() == "A decision.")
  for type in ["response.failed", "response.incomplete", "error"] {
    #expect(throws: ChatGPTError.self) { try stream.consume(Data("{\"type\":\"\(type)\"}".utf8)) }
  }
  #expect(throws: ChatGPTError.self) { try SummaryStream().result() }
}

@Test func tokenValidationRejectsUnsignedTokens() throws {
  let header = ChatGPTProtocol.base64URL(Data(#"{"alg":"none","kid":"x"}"#.utf8))
  let payload = ChatGPTProtocol.base64URL(Data(#"{"sub":"attacker"}"#.utf8))
  #expect(throws: ChatGPTError.self) {
    try ChatGPTProtocol.validateIDToken(
      "\(header).\(payload).", jwks: Data(#"{"keys":[]}"#.utf8), clientID: "client", nonce: "nonce")
  }
}

@Test func oauthFormEscapesReservedCharacters() {
  #expect(
    String(decoding: ChatGPTProtocol.form(["code": "a+b&c=d"]), as: UTF8.self)
      == "code=a%2Bb%26c%3Dd")
}

@Test func tokenValidationChecksSignatureAndBoundClaims() throws {
  let key = try #require(
    SecKeyCreateRandomKey(
      [
        kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048,
      ] as CFDictionary, nil))
  let publicKey = try #require(SecKeyCopyPublicKey(key))
  let der = try #require(SecKeyCopyExternalRepresentation(publicKey, nil)) as Data
  // The Security framework exports an RSA public key as a DER sequence of two integers.
  let bytes = Array(der)
  var offset = 1
  func length() -> Int {
    let first = Int(bytes[offset])
    offset += 1
    if first < 128 { return first }
    var result = 0
    for _ in 0..<(first & 127) {
      result = result * 256 + Int(bytes[offset])
      offset += 1
    }
    return result
  }
  _ = length()
  func integer() -> Data {
    offset += 1
    let count = length()
    let value = Data(bytes[offset..<(offset + count)])
    offset += count
    return value.first == 0 ? value.dropFirst() : value
  }
  let modulus = integer()
  let exponent = integer()
  let jwks = try JSONSerialization.data(withJSONObject: [
    "keys": [
      [
        "kid": "test", "kty": "RSA", "n": ChatGPTProtocol.base64URL(modulus),
        "e": ChatGPTProtocol.base64URL(exponent),
      ]
    ]
  ])
  func signed(
    expiry: Double = Date().timeIntervalSince1970 + 300, issuer: String = "https://auth.openai.com"
  ) throws -> String {
    let header = ChatGPTProtocol.base64URL(Data(#"{"alg":"RS256","kid":"test"}"#.utf8))
    let claims = try JSONSerialization.data(withJSONObject: [
      "iss": issuer, "aud": "client", "nonce": "nonce", "sub": "subject",
      "email": "person@example.com", "exp": expiry,
    ])
    let message = "\(header).\(ChatGPTProtocol.base64URL(claims))"
    let signature = try #require(
      SecKeyCreateSignature(
        key, .rsaSignatureMessagePKCS1v15SHA256, Data(message.utf8) as CFData, nil))
    return "\(message).\(ChatGPTProtocol.base64URL(signature as Data))"
  }
  let token = try signed()
  let identity = try ChatGPTProtocol.validateIDToken(
    token, jwks: jwks, clientID: "client", nonce: "nonce")
  #expect(identity.0 == "subject")
  #expect(identity.1 == "person@example.com")
  for (client, nonce) in [("other", "nonce"), ("client", "other")] {
    #expect(throws: ChatGPTError.self) {
      try ChatGPTProtocol.validateIDToken(token, jwks: jwks, clientID: client, nonce: nonce)
    }
  }
  for invalid in [try signed(expiry: 0), try signed(issuer: "https://example.com")] {
    #expect(throws: ChatGPTError.self) {
      try ChatGPTProtocol.validateIDToken(invalid, jwks: jwks, clientID: "client", nonce: "nonce")
    }
  }
}
