import Testing

@testable import MinutesCore

@Test func meetingSearchScopesSeparateTitlesFromTranscriptContent() {
  let meeting = Meeting(
    title: "Design Review",
    utterances: [Utterance(speaker: "One", start: 0, end: 1, text: "Discuss the toolbar")]
  )
  for scope in MeetingSearchScope.allCases {
    #expect(scope.matches(meeting, query: ""))
    #expect(scope.matches(meeting, query: "DESIGN"))
    #expect(!scope.matches(meeting, query: "missing"))
  }
  #expect(!MeetingSearchScope.titles.matches(meeting, query: "toolbar"))
  #expect(MeetingSearchScope.fullTranscript.matches(meeting, query: "TOOLBAR"))
}
