import CryptoKit
import Foundation
import Security

struct ChatGPTError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
  init(_ message: String) { self.message = message }
}

enum ChatGPTProtocol {
  static let resource = "https://api.openai.com/v1"
  static func base64URL(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }
  static func decodeBase64URL(_ text: String) throws -> Data {
    var value = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(
      of: "_", with: "/")
    value += String(repeating: "=", count: (4 - value.count % 4) % 4)
    guard let data = Data(base64Encoded: value) else {
      throw ChatGPTError("Invalid sign-in token.")
    }
    return data
  }
  static func random() throws -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw ChatGPTError("Could not prepare secure sign-in.")
    }
    return base64URL(Data(bytes))
  }
  static func form(_ values: [String: String]) -> Data {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    return Data(
      values.sorted { $0.key < $1.key }.map {
        "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
      }.joined(separator: "&").utf8)
  }
  static func callback(_ url: URL, state: String, clientID: String?) throws -> (String, String) {
    guard url.path == "/auth/callback",
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
      items.filter({ $0.name == "state" }).count == 1,
      items.first(where: { $0.name == "state" })?.value == state
    else { throw ChatGPTError("Sign-in response did not match this attempt.") }
    func value(_ name: String) -> String? {
      let matches = items.filter { $0.name == name }
      return matches.count == 1 ? matches[0].value : nil
    }
    if value("error") != nil {
      throw ChatGPTError("ChatGPT sign-in was declined. Please try again.")
    }
    guard let code = value("code"), !code.isEmpty,
      let issued = value("client_id") ?? clientID, !issued.isEmpty,
      issued != "dynamic_agent_client",
      clientID == nil || issued == clientID
    else { throw ChatGPTError("ChatGPT did not return the expected registration.") }
    return (code, issued)
  }

  static func validateIDToken(_ token: String, jwks: Data, clientID: String, nonce: String) throws
    -> (String, String)
  {
    let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 3,
      let header = try JSONSerialization.jsonObject(with: decodeBase64URL(parts[0]))
        as? [String: Any],
      header["alg"] as? String == "RS256", let kid = header["kid"] as? String,
      let keys = (try JSONSerialization.jsonObject(with: jwks) as? [String: Any])?["keys"]
        as? [[String: Any]],
      let jwk = keys.first(where: { $0["kid"] as? String == kid && $0["kty"] as? String == "RSA" }),
      let n = jwk["n"] as? String, let e = jwk["e"] as? String
    else { throw ChatGPTError("Could not verify ChatGPT's signing key.") }
    func der(_ tag: UInt8, _ bytes: Data) -> Data {
      let count = bytes.count
      let length: [UInt8] =
        count < 128
        ? [UInt8(count)]
        : count < 256 ? [0x81, UInt8(count)] : [0x82, UInt8(count >> 8), UInt8(count & 255)]
      return Data([tag] + length) + bytes
    }
    func integer(_ value: String) throws -> Data {
      var bytes = try decodeBase64URL(value)
      if let first = bytes.first, first & 0x80 != 0 { bytes.insert(0, at: 0) }
      return der(0x02, bytes)
    }
    let keyData = try der(0x30, integer(n) + integer(e))
    guard
      let key = SecKeyCreateWithData(
        keyData as CFData,
        [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic]
          as CFDictionary, nil),
      SecKeyVerifySignature(
        key, .rsaSignatureMessagePKCS1v15SHA256, Data("\(parts[0]).\(parts[1])".utf8) as CFData,
        try decodeBase64URL(parts[2]) as CFData, nil),
      let claims = try JSONSerialization.jsonObject(with: decodeBase64URL(parts[1]))
        as? [String: Any]
    else { throw ChatGPTError("ChatGPT identity signature is invalid.") }
    let audiences = claims["aud"] as? [String] ?? (claims["aud"] as? String).map { [$0] } ?? []
    guard claims["iss"] as? String == "https://auth.openai.com", audiences.contains(clientID),
      audiences.count == 1 || claims["azp"] as? String == clientID,
      let expiry = claims["exp"] as? Double, expiry > Date().timeIntervalSince1970,
      claims["nonce"] as? String == nonce, let subject = claims["sub"] as? String, !subject.isEmpty
    else { throw ChatGPTError("ChatGPT identity claims did not match this sign-in.") }
    return (subject, claims["email"] as? String ?? "ChatGPT account")
  }
}

/// Publish output only after a successful terminal event; partial text is never a summary.
struct SummaryStream {
  private(set) var text = ""
  private(set) var completed = false
  mutating func consume(_ data: Data) throws {
    guard let event = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let type = event["type"] as? String
    else { throw ChatGPTError("Invalid summary response.") }
    switch type {
    case "response.output_text.delta": text += event["delta"] as? String ?? ""
    case "response.completed":
      guard let response = event["response"] as? [String: Any],
        response["status"] as? String == "completed"
      else {
        throw ChatGPTError("The summary did not complete. Try again.")
      }
      completed = true
    case "response.failed", "response.incomplete", "error":
      throw ChatGPTError(
        "ChatGPT could not finish the summary. Check your plan usage or try again.")
    default: break
    }
  }
  func result() throws -> String {
    let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard completed, !result.isEmpty else {
      throw ChatGPTError("The summary stream ended without a complete summary. Try again.")
    }
    return result
  }
}
