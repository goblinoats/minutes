import Foundation
import Testing

@testable import MinutesCore

@Test func summariesExportBeforeTranscriptAndSurviveReload() throws {
  var meeting = Meeting(
    title: "Planning", utterances: [.init(speaker: "A", start: 0, end: 3, text: "Ship Friday.")])
  meeting.summary = MeetingSummary(
    markdown: "### Decisions\n- Ship Friday.", meeting: meeting, model: "test-model")
  let restored = try JSONDecoder().decode(Meeting.self, from: JSONEncoder().encode(meeting))
  let markdown = MarkdownExporter.render(restored)
  #expect(
    markdown.range(of: "## Summary")!.lowerBound < markdown.range(of: "## Transcript")!.lowerBound)
  #expect(markdown.contains("### Decisions\n- Ship Friday."))
  #expect(markdown.contains("**A** · 00:00"))
  #expect(restored.summary == meeting.summary)
}

@Test func summaryInvalidatesWhenSourceChanges() {
  var meeting = Meeting(
    title: "Planning", utterances: [.init(speaker: "A", start: 0, end: 3, text: "Ship Friday.")])
  meeting.summary = MeetingSummary(markdown: "Ship Friday.", meeting: meeting, model: "test")
  #expect(meeting.currentSummary != nil)
  meeting.speakerNames["A"] = "Alice"
  #expect(meeting.currentSummary == nil)
  #expect(!MarkdownExporter.render(meeting).contains("## Summary"))
  #expect(meeting.reprocessedDraft(options: .init()).summary == nil)
}

@Test func oldMeetingsStillDecodeWithoutSummary() throws {
  let meeting = Meeting(title: "Old")
  let data = try JSONEncoder().encode(meeting)
  #expect(!String(decoding: data, as: UTF8.self).contains("summary"))
  #expect(try JSONDecoder().decode(Meeting.self, from: data).summary == nil)
  #expect(!MarkdownExporter.render(meeting).contains("## Summary"))
}
