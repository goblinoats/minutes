import Foundation

public enum TranscriptSearch {
  public struct Options: Equatable {
    public enum Mode: Equatable { case contains, startsWith }
    public var ignoreCase = true
    public var wrapAround = true
    public var mode: Mode = .contains
    public init() {}
  }

  public struct Match: Equatable {
    public let utteranceID: UUID
    public let range: Range<String.Index>
  }

  public static func matches(
    in utterances: [Utterance], query: String, options: Options = Options()
  ) -> [Match] {
    utterances.flatMap { utterance in
      ranges(in: utterance.text, query: query, options: options).map {
        Match(utteranceID: utterance.id, range: $0)
      }
    }
  }

  /// Literal, case- and accent-insensitive matches, shared by navigation and highlighting.
  public static func ranges(
    in text: String, query: String, options: Options = Options()
  ) -> [Range<String.Index>] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }
    var matches: [Range<String.Index>] = []
    var wordStarts: Set<String.Index> = []
    if options.mode == .startsWith {
      text.enumerateSubstrings(
        in: text.startIndex..<text.endIndex,
        options: [.byWords, .substringNotRequired]
      ) { _, range, _, _ in
        wordStarts.insert(range.lowerBound)
      }
    }
    let comparison: String.CompareOptions =
      options.ignoreCase ? [.caseInsensitive, .diacriticInsensitive] : [.diacriticInsensitive]
    var start = text.startIndex
    while start < text.endIndex,
      let range = text.range(
        of: query, options: comparison,
        range: start..<text.endIndex)
    {
      if options.mode == .contains || wordStarts.contains(range.lowerBound) {
        matches.append(range)
      }
      start = range.upperBound
    }
    return matches
  }

  public static func nextIndex(
    from index: Int, offset: Int, count: Int, wrapAround: Bool
  ) -> Int? {
    guard count > 0 else { return nil }
    let next = index + offset
    if wrapAround { return ((next % count) + count) % count }
    return (0..<count).contains(next) ? next : nil
  }
}
