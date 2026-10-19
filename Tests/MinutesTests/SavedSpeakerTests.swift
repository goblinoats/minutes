import Foundation
import MinutesCore
import Testing

@testable import Minutes

@Test @MainActor func savedSpeakersPersistAndApplyWithoutLosingTimings() throws {
  let suite = "MinutesTests.\(UUID().uuidString)"
  let preferences = try #require(UserDefaults(suiteName: suite))
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
  defer {
    preferences.removePersistentDomain(forName: suite)
    try? FileManager.default.removeItem(at: directory)
  }
  let model = AppModel(supportDirectory: directory, preferences: preferences)
  model.exportDirectory = directory.appendingPathComponent("exports")
  model.addSavedSpeaker("  Alice  ")
  model.addSavedSpeaker("alice")
  model.addSavedSpeaker(" ")
  #expect(model.savedSpeakers == ["Alice"])
  let utterances = SpeakerAlignment.align(
    words: [.init(text: "Hello", start: 1, end: 2)], spans: [], fixedSpeaker: "Speaker 1")
  let meeting = Meeting(title: "Test", utterances: utterances)
  model.renameSpeaker("Speaker 1", to: "Alice", in: meeting)
  #expect(model.error == nil)
  let reloaded = AppModel(supportDirectory: directory, preferences: preferences)
  #expect(reloaded.savedSpeakers == ["Alice"])
  let saved = try #require(reloaded.selectedMeeting)
  #expect(saved.name(for: "Speaker 1") == "Alice")
  #expect(saved.utterances == utterances)
  let markdown = try String(
    contentsOf: model.exportDirectory.appendingPathComponent(MarkdownExporter.filename(saved)),
    encoding: .utf8)
  #expect(markdown.contains("**Alice**"))
  reloaded.savedSpeakers = []
  let removed = AppModel(supportDirectory: directory, preferences: preferences)
  #expect(removed.savedSpeakers.isEmpty)
  #expect(removed.selectedMeeting?.name(for: "Speaker 1") == "Alice")
}

@Test @MainActor func defaultMicrophoneSpeakerPersistsAndNamesNewTranscripts() throws {
  let suite = "MinutesTests.\(UUID().uuidString)"
  let preferences = try #require(UserDefaults(suiteName: suite))
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
  defer {
    preferences.removePersistentDomain(forName: suite)
    try? FileManager.default.removeItem(at: directory)
  }
  let model = AppModel(supportDirectory: directory, preferences: preferences)
  let utterances =
    SpeakerAlignment.align(
      words: [.init(text: "Hello", start: 1, end: 2)], spans: [], fixedSpeaker: "You")
    + [Utterance(speaker: "Speaker 1", start: 3, end: 4, text: "Hi")]
  var meeting = Meeting(title: "Test", utterances: utterances)
  model.applyDefaultMicrophoneSpeaker(to: &meeting)
  #expect(meeting.name(for: "You") == "You")

  model.defaultMicrophoneSpeaker = "  Jack  "
  let reloaded = AppModel(supportDirectory: directory, preferences: preferences)
  #expect(reloaded.defaultMicrophoneSpeaker == "  Jack  ")
  reloaded.applyDefaultMicrophoneSpeaker(to: &meeting)
  #expect(meeting.name(for: "You") == "Jack")
  #expect(meeting.name(for: "Speaker 1") == "Speaker 1")
  #expect(meeting.utterances == utterances)
  #expect(MarkdownExporter.render(meeting).contains("**Jack**"))
  let store = MeetingStore(directory: directory.appendingPathComponent("Meetings"))
  try store.save(meeting)

  reloaded.defaultMicrophoneSpeaker = "Someone Else"
  reloaded.applyDefaultMicrophoneSpeaker(to: &meeting)
  #expect(meeting.name(for: "You") == "Jack")
  #expect(try store.load().first?.name(for: "You") == "Jack")
  var regenerated = meeting.reprocessedDraft(options: reloaded.defaultTranscriptionOptions)
  regenerated.utterances = utterances
  reloaded.applyDefaultMicrophoneSpeaker(to: &regenerated)
  #expect(regenerated.name(for: "You") == "Someone Else")

  reloaded.defaultMicrophoneSpeaker = " \n "
  var blank = Meeting(title: "Blank", utterances: utterances)
  reloaded.applyDefaultMicrophoneSpeaker(to: &blank)
  #expect(blank.speakerNames["You"] == nil)
  #expect(blank.name(for: "You") == "You")
  reloaded.defaultMicrophoneSpeaker = "Jack"
  var remoteOnly = Meeting(title: "Remote", utterances: [utterances[1]])
  reloaded.applyDefaultMicrophoneSpeaker(to: &remoteOnly)
  #expect(remoteOnly.speakerNames.isEmpty)
}
