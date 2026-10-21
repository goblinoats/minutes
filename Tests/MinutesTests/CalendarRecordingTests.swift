import Foundation
import MinutesCore
import Testing

@testable import Minutes

@Test @MainActor func calendarRecordOpensNewMeetingNamedForTheEvent() throws {
  let suite = "MinutesTests.\(UUID().uuidString)"
  let preferences = try #require(UserDefaults(suiteName: suite))
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
  defer {
    preferences.removePersistentDomain(forName: suite)
    try? FileManager.default.removeItem(at: directory)
  }
  let model = AppModel(supportDirectory: directory, preferences: preferences)
  let previous = Meeting(title: "Earlier")
  model.meetings = [previous]
  model.selection = previous.id
  model.title = "Leftover draft"
  model.recordingSystemSpeakers = 4
  let event = CalendarMeeting(
    eventID: "standup", title: "Design Review", start: .now, end: .now.addingTimeInterval(1800),
    url: try #require(URL(string: "https://meet.google.com/abc-defg-hij")))
  model.calendarMonitor.invitations = [event]

  model.prepareRecording(for: event)

  #expect(model.selection == nil)
  #expect(model.title == "Design Review")
  #expect(model.recordingSystemSpeakers == 0)
  #expect(model.preparedCalendarMeeting == event)
  #expect(model.calendarMonitor.invitations.isEmpty)

  model.newMeeting()
  #expect(model.title.isEmpty)
  #expect(model.preparedCalendarMeeting == nil)
}
