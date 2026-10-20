import FluidAudio
import MinutesCore
import Testing

@testable import Minutes

private func token(_ text: String, _ start: Double) -> TokenTiming {
  TokenTiming(token: text, tokenId: 0, startTime: start, endTime: start + 0.2, confidence: 1)
}

@Test func boostReplacesOnlyTheWordsInsideTheTermSpan() {
  let words = [
    TimedWord(text: "Ask", start: 0, end: 0.3),
    TimedWord(text: "Shiv", start: 0.4, end: 0.6),
    TimedWord(text: "on,", start: 0.6, end: 0.9),
    TimedWord(text: "then", start: 1.2, end: 1.4),
    TimedWord(text: "graph", start: 2, end: 2.3),
    TimedWord(text: "Ana.", start: 2.3, end: 2.7),
  ]
  let boosted = VocabularyBooster.apply(
    [.init(term: "Grafana", start: 2, end: 2.6), .init(term: "Siobhan", start: 0.4, end: 0.88)],
    to: words)
  #expect(boosted.map(\.text) == ["Ask", "Siobhan,", "then", "Grafana."])
  #expect(boosted[1].start == 0.4 && boosted[1].end == 0.9)
  #expect(boosted[3].start == 2 && boosted[3].end == 2.7)
  #expect(boosted[0] == words[0] && boosted[2] == words[3])
  #expect(VocabularyBooster.apply([], to: words) == words)
}

@Test func boostWindowsCutAtTheLongestPauseAndCoverEveryToken() {
  // Words every 10 s, with a long pause before the word at 47 s.
  let starts: [Double] = [0, 10, 20, 31, 47, 52, 61, 70, 130, 135]
  let tokens = starts.flatMap { [token("▁w", $0), token("x", $0 + 0.2)] }
  let windows = VocabularyBooster.windows(tokens, maxSeconds: 60)
  #expect(windows.first?.lowerBound == 0 && windows.last?.upperBound == tokens.count)
  #expect(zip(windows, windows.dropFirst()).allSatisfy { $0.upperBound == $1.lowerBound })
  #expect(windows.map { tokens[$0.lowerBound].startTime } == [0, 47, 130])
  for window in windows {
    #expect(isWordBoundary(tokens[window.lowerBound].token))
    #expect(tokens[window.upperBound - 1].startTime - tokens[window.lowerBound].startTime < 60)
  }
}
