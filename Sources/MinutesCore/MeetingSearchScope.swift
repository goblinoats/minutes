import Foundation

public enum MeetingSearchScope: Int, CaseIterable {
  case titles
  case fullTranscript

  public var title: String {
    switch self {
    case .titles: "Meeting Titles"
    case .fullTranscript: "Full Transcript"
    }
  }

  public func matches(_ meeting: Meeting, query: String) -> Bool {
    query.isEmpty || meeting.title.localizedCaseInsensitiveContains(query)
      || (self == .fullTranscript
        && meeting.utterances.contains { $0.text.localizedCaseInsensitiveContains(query) })
  }
}
