import AVFoundation
import Foundation
import MinutesCore
import Testing

@testable import Minutes

private final class SummaryStub: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    var body: String
    if request.url?.path == "/v1/models" {
      body = #"{"models":[{"slug":"test-model","display_name":"Test model","visibility":"list"}]}"#
    } else {
      body =
        "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Ship Friday.\"}\n\ndata: {\"type\":\"response.completed\",\"response\":{\"status\":\"completed\"}}\n\n"
    }
    if request.value(forHTTPHeaderField: "Authorization") == "Bearer truncated",
      request.url?.path == "/v1/responses"
    {
      body = "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Partial summary\"}\n\n"
    }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: 200, httpVersion: nil,
      headerFields: [
        "Content-Type": request.url?.path == "/v1/models" ? "application/json" : "text/event-stream"
      ])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    // Fragment transport data to prove stream parsing is independent of chunk boundaries.
    for chunk in body.utf8 { client?.urlProtocol(self, didLoad: Data([chunk])) }
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

@Test @MainActor func chatGPTSummaryTraversesModelDiscoveryAndStreaming() async throws {
  let suite = "MinutesTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  defaults.set("test-client", forKey: "chatGPTAccount")
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [SummaryStub.self]
  let session = URLSession(configuration: configuration)
  defer { session.invalidateAndCancel() }
  let connection = ChatGPTConnection(
    defaults: defaults, session: session,
    initialAccounts: [
      .init(
        id: "test-client", subject: "test-subject", email: "test@example.com", accessToken: "fake",
        refreshToken: "fake", expiresAt: Date().addingTimeInterval(600))
    ])
  let meeting = Meeting(
    title: "Planning", utterances: [.init(speaker: "Alice", start: 0, end: 2, text: "Ship Friday.")]
  )
  let summary = try await connection.summarize(meeting)
  #expect(summary.markdown == "Ship Friday.")
  #expect(summary.model == "test-model")
  #expect(summary.inputDigest == meeting.summaryInputDigest)
  #expect(!connection.busy)
  #expect(!connection.automaticSummaries)
}

@Test(arguments: ["fake", "truncated", "edited", "deleted"]) @MainActor
func summaryWorkflowPersistsSuccessAndPreservesTranscriptOnFailure(token: String) async throws {
  let suite = "MinutesTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
  defer {
    defaults.removePersistentDomain(forName: suite)
    try? FileManager.default.removeItem(at: directory)
  }
  defaults.set("test-client", forKey: "chatGPTAccount")
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [SummaryStub.self]
  let session = URLSession(configuration: configuration)
  defer { session.invalidateAndCancel() }
  let connection = ChatGPTConnection(
    defaults: defaults, session: session,
    initialAccounts: [
      .init(
        id: "test-client", subject: "test-subject", email: "test@example.com",
        accessToken: token, refreshToken: "fake", expiresAt: Date().addingTimeInterval(600))
    ])
  let meeting = Meeting(
    title: "Planning", utterances: [.init(speaker: "Alice", start: 0, end: 2, text: "Ship Friday.")]
  )
  let store = MeetingStore(directory: directory.appendingPathComponent("Meetings"))
  try store.save(meeting)
  let exportDirectory = directory.appendingPathComponent("exports")
  let export = try MarkdownExporter.write(meeting, to: exportDirectory)
  let before = try Data(contentsOf: export)
  let model = AppModel(supportDirectory: directory, preferences: defaults, chatGPT: connection)
  model.exportDirectory = exportDirectory
  let recording = directory.appendingPathComponent("Recordings/\(meeting.id.uuidString)")
  try FileManager.default.createDirectory(at: recording, withIntermediateDirectories: true)
  let audio = recording.appendingPathComponent("remote.caf")
  let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
  let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
  buffer.frameLength = 48_000
  for frame in 0..<48_000 { buffer.floatChannelData![0][frame] = 0 }
  do {
    let file = try AVAudioFile(forWriting: audio, settings: format.settings)
    try file.write(from: buffer)
  }
  let tracks = AudioTracks(remote: audio, microphone: nil, remoteOffset: 0, microphoneOffset: 0)
  try JSONEncoder().encode(tracks).write(to: recording.appendingPathComponent("tracks.json"))
  model.play(meeting, from: 0.25)
  #expect(model.playback.isPlaying)
  defer { model.playback.stop() }
  model.generateSummary(meeting)
  #expect(model.playback.isPlaying)
  model.play(meeting, from: 1)
  #expect(model.playback.position == 1)
  #expect(model.playback.isPlaying)
  #expect(!model.isBusy)
  #expect(model.summarizingMeetingID == meeting.id)
  if token == "edited" {
    model.renameSpeaker("Alice", to: "Alicia", in: meeting)
  } else if token == "deleted" {
    model.meetings.removeAll { $0.id == meeting.id }
    try FileManager.default.removeItem(
      at: store.directory.appendingPathComponent(meeting.id.uuidString + ".json"))
  }
  model.selection = nil
  for _ in 0..<200 {
    if model.summarizingMeetingID == nil { break }
    try await Task.sleep(for: .milliseconds(10))
  }
  #expect(!model.isBusy)
  #expect(model.summarizingMeetingID == nil)
  #expect(model.selection == nil)
  if token == "truncated" {
    #expect(model.summaryError?.contains("complete summary") == true)
    #expect(try store.load().first == meeting)
    #expect(try Data(contentsOf: export) == before)
    #expect(model.selectedMeeting?.summary == nil)
  } else if token == "edited" {
    #expect(model.summaryError?.contains("transcript changed") == true)
    let saved = try #require(store.load().first)
    #expect(saved.speakerNames["Alice"] == "Alicia")
    #expect(saved.summary == nil)
  } else if token == "deleted" {
    #expect(try store.load().isEmpty)
    #expect(model.meetings.isEmpty)
    #expect(try Data(contentsOf: export) == before)
  } else {
    #expect(model.error == nil)
    #expect(model.summaryError == nil)
    let saved = try #require(store.load().first)
    #expect(saved.currentSummary?.markdown == "Ship Friday.")
    #expect(saved.utterances == meeting.utterances)
    #expect(try String(contentsOf: export, encoding: .utf8) == MarkdownExporter.render(saved))
    #expect(MarkdownExporter.owns(export, meeting: saved))
  }
}
