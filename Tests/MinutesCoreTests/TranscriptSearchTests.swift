import Testing

@testable import MinutesCore

@Test func transcriptSearchOptionsRespectCaseAndWordStarts() {
  var options = TranscriptSearch.Options()
  let text = "The other theme, the end."
  #expect(TranscriptSearch.ranges(in: text, query: "the", options: options).count == 4)
  options.ignoreCase = false
  #expect(TranscriptSearch.ranges(in: text, query: "the", options: options).count == 3)
  options.mode = .startsWith
  #expect(
    TranscriptSearch.ranges(in: text, query: "the", options: options).map {
      String(text[$0])
    } == ["the", "the"])
  options.ignoreCase = true
  #expect(TranscriptSearch.ranges(in: text, query: "the", options: options).count == 3)
  #expect(TranscriptSearch.ranges(in: "a café; café!", query: "cafe", options: options).count == 2)
}

@Test func transcriptSearchWrapCanBeDisabledInBothDirections() {
  #expect(TranscriptSearch.nextIndex(from: 0, offset: -1, count: 3, wrapAround: true) == 2)
  #expect(TranscriptSearch.nextIndex(from: 2, offset: 1, count: 3, wrapAround: true) == 0)
  #expect(TranscriptSearch.nextIndex(from: 0, offset: -1, count: 3, wrapAround: false) == nil)
  #expect(TranscriptSearch.nextIndex(from: 2, offset: 1, count: 3, wrapAround: false) == nil)
  #expect(TranscriptSearch.nextIndex(from: 1, offset: 1, count: 3, wrapAround: false) == 2)
  #expect(TranscriptSearch.nextIndex(from: 0, offset: 1, count: 0, wrapAround: true) == nil)
}

@Test func transcriptSearchCountsEachOccurrenceInReadingOrder() {
  let first = Utterance(speaker: "One", start: 0, end: 3, text: "The plan, then the review.")
  let second = Utterance(speaker: "Two", start: 3, end: 4, text: "THE end.")
  let matches = TranscriptSearch.matches(in: [first, second], query: "the")
  #expect(matches.count == 4)
  #expect(matches.map(\.utteranceID) == [first.id, first.id, first.id, second.id])
  #expect(matches.prefix(3).map { String(first.text[$0.range]) } == ["The", "the", "the"])
  #expect(matches[0].range != matches[1].range)
  #expect(TranscriptSearch.matches(in: [first, second], query: " ").isEmpty)
}

@Test func transcriptSearchMatchesLiteralPhrasesIgnoringCaseAndAccents() {
  let text = "Café plans. CAFÉ plans. Other plans."
  let ranges = TranscriptSearch.ranges(in: text, query: " café PLANS ")
  #expect(ranges.map { String(text[$0]) } == ["Café plans", "CAFÉ plans"])
  #expect(TranscriptSearch.ranges(in: "a.b aab", query: "a.b").count == 1)
}

@Test func transcriptSearchHandlesEmptyMissingAndUnicodeMatches() {
  #expect(TranscriptSearch.ranges(in: "Hello", query: " \n ").isEmpty)
  #expect(TranscriptSearch.ranges(in: "", query: "hello").isEmpty)
  #expect(TranscriptSearch.ranges(in: "Hello", query: "goodbye").isEmpty)
  let text = "你好, 你好"
  #expect(TranscriptSearch.ranges(in: text, query: "你好").map { String(text[$0]) } == ["你好", "你好"])
  #expect(TranscriptSearch.ranges(in: "aaaa", query: "aa").count == 2)
}
