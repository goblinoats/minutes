import CryptoKit
import Foundation

public struct MeetingSummary: Codable, Equatable, Sendable {
  public var markdown: String
  public var inputDigest: String
  public var model: String
  public var generatedAt: Date

  public init(markdown: String, meeting: Meeting, model: String) {
    self.markdown = markdown
    self.inputDigest = meeting.summaryInputDigest
    self.model = model
    self.generatedAt = Date()
  }
}

extension Meeting {
  public var summaryInput: String {
    var transcript = self
    transcript.summary = nil
    return MarkdownExporter.render(transcript)
  }

  public var summaryInputDigest: String {
    SHA256.hash(data: Data(summaryInput.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  public var currentSummary: MeetingSummary? {
    guard let summary, summary.inputDigest == summaryInputDigest else { return nil }
    return summary
  }
}
