import FluidAudio
import Foundation
import MinutesCore

/// Acoustic vocabulary boosting. A separate English CTC model scores the
/// user's dictionary terms against the audio under each transcribed word, and
/// words the CTC evidence prefers as a term are replaced in place. Only the
/// replaced words change; every other word keeps its original timing.
struct VocabularyBooster: Sendable {
  struct Replacement: Equatable, Sendable {
    var term: String
    var start: Double
    var end: Double
    var evidence = ""
  }

  // Bounds memory on long tracks: one window of audio and CTC log
  // probabilities (about 6 MB per minute) is held at a time.
  static let windowSeconds = 60.0
  static let sampleRate = 16_000
  // FluidAudio's floor (0.55 for a 12-term dictionary) let "store" become an
  // unspoken "Saoirse" (0.57) in synthesized meetings; every genuine
  // correction measured 0.67 or more.
  // See verification/vocabulary-boosting.
  static let minimumSimilarity: Float = 0.6

  private let spotter: CtcKeywordSpotter
  private let rescorer: VocabularyRescorer
  private let vocabulary: CustomVocabularyContext
  private let sizeConfig: ContextBiasingConstants.VocabSizeConfig

  static func modelDirectory(in models: URL) -> URL {
    models.appendingPathComponent(Repo.parakeetCtc110m.folderName, isDirectory: true)
  }

  /// Nil when no term produces CTC tokens.
  init?(
    terms: [String], models: CtcModels, directory: URL,
    config: VocabularyRescorer.Config = .default, minSimilarity: Float = minimumSimilarity
  ) async throws {
    let tokenizer = try await CtcTokenizer.load(from: directory)
    let vocabularyTerms = terms.compactMap { text -> CustomVocabularyTerm? in
      let ids = tokenizer.encode(text)
      return ids.isEmpty ? nil : CustomVocabularyTerm(text: text, ctcTokenIds: ids)
    }
    guard !vocabularyTerms.isEmpty else { return nil }
    vocabulary = CustomVocabularyContext(terms: vocabularyTerms, minSimilarity: minSimilarity)
    spotter = CtcKeywordSpotter(models: models, blankId: models.vocabulary.count)
    rescorer = try await VocabularyRescorer.create(
      spotter: spotter, vocabulary: vocabulary, config: config, ctcModelDirectory: directory)
    sizeConfig = ContextBiasingConstants.rescorerConfig(forVocabSize: vocabularyTerms.count)
  }

  /// Rescores `tokens` (absolute times in `audio`) and applies the accepted
  /// replacements to `words`, which were built from the same tokens.
  func boost(_ words: [TimedWord], tokens: [TokenTiming], audio: URL) async throws -> [TimedWord] {
    Self.apply(try await replacements(tokens: tokens, audio: audio), to: words)
  }

  func replacements(tokens: [TokenTiming], audio: URL) async throws -> [Replacement] {
    guard !tokens.isEmpty else { return [] }
    let (source, _) = try AudioSourceFactory().makeDiskBackedSource(
      from: audio, targetSampleRate: Self.sampleRate)
    defer { source.cleanup() }
    let rate = Double(Self.sampleRate)
    var replacements: [Replacement] = []
    for window in Self.windows(tokens, maxSeconds: Self.windowSeconds) {
      // Pad past the last token start: its end time may be unreliable.
      let start = max(0, tokens[window.lowerBound].startTime - 1)
      let end = tokens[window.upperBound - 1].startTime + 2
      let offset = Int(start * rate)
      let count = min(source.sampleCount - offset, Int((end - start) * rate))
      guard count > 0 else { continue }
      var samples = [Float](repeating: 0, count: count)
      try samples.withUnsafeMutableBufferPointer {
        try source.copySamples(into: $0.baseAddress!, offset: offset, count: count)
      }
      let local = tokens[window].map {
        TokenTiming(
          token: $0.token, tokenId: $0.tokenId, startTime: $0.startTime - start,
          endTime: $0.endTime - start, confidence: $0.confidence)
      }
      let spot = try await spotter.spotKeywordsWithLogProbs(
        audioSamples: samples, customVocabulary: vocabulary)
      guard !spot.logProbs.isEmpty else { continue }
      let evidence = rescorer.ctcTokenEvaluateCandidates(
        transcript: local.map(\.token).joined().replacingOccurrences(of: "▁", with: " ")
          .trimmingCharacters(in: .whitespaces),
        tokenTimings: local, logProbs: spot.logProbs, frameDuration: spot.frameDuration,
        cbw: sizeConfig.cbw, marginSeconds: 0.5,
        minSimilarity: max(sizeConfig.minSimilarity, vocabulary.minSimilarity))
      for candidate in evidence.candidates where candidate.legacyOutcome == .applied {
        guard let from = candidate.startTime, let to = candidate.endTime else { continue }
        replacements.append(
          .init(
            term: candidate.canonicalTerm, start: from + start, end: to + start,
            evidence: "\(candidate.basePhrase) -> \(candidate.canonicalTerm) "
              + "(\(candidate.origin.rawValue), similarity \(candidate.similarity))"))
      }
    }
    return replacements
  }

  /// Splits tokens into windows no longer than `maxSeconds`, cutting before the
  /// word with the longest preceding pause in each window's second half so a
  /// term is never split across windows.
  static func windows(_ tokens: [TokenTiming], maxSeconds: Double) -> [Range<Int>] {
    var windows: [Range<Int>] = []
    var lower = 0
    while lower < tokens.count {
      let first = tokens[lower].startTime
      var upper = lower + 1
      while upper < tokens.count, tokens[upper].startTime < first + maxSeconds { upper += 1 }
      if upper < tokens.count {
        var bestGap = -1.0
        for index in (lower + 1)..<upper
        where isWordBoundary(tokens[index].token)
          && tokens[index].startTime >= first + maxSeconds / 2
        {
          let gap = tokens[index].startTime - tokens[index - 1].startTime
          if gap > bestGap {
            bestGap = gap
            upper = index
          }
        }
      }
      windows.append(lower..<upper)
      lower = upper
    }
    return windows
  }

  /// Replaces each run of words starting inside a replacement's span with one
  /// word spelled as the term, spanning the run and keeping its trailing
  /// punctuation.
  static func apply(_ replacements: [Replacement], to words: [TimedWord]) -> [TimedWord] {
    var result: [TimedWord] = []
    var index = 0
    let sorted = replacements.sorted { $0.start < $1.start }
    var next = 0
    let tolerance = 0.001
    while index < words.count {
      while next < sorted.count, sorted[next].end < words[index].start - tolerance { next += 1 }
      guard next < sorted.count, words[index].start >= sorted[next].start - tolerance,
        words[index].start < sorted[next].end
      else {
        result.append(words[index])
        index += 1
        continue
      }
      let replacement = sorted[next]
      var last = index
      while last + 1 < words.count, words[last + 1].start < replacement.end - tolerance {
        last += 1
      }
      let trailing = String(
        words[last].text.reversed().prefix {
          $0.unicodeScalars.allSatisfy(CharacterSet.punctuationCharacters.contains)
        }.reversed())
      result.append(
        TimedWord(
          text: replacement.term + trailing, start: words[index].start,
          end: max(words[last].end, words[index].start)))
      index = last + 1
      next += 1
    }
    return result
  }
}
