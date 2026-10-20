import Foundation

public struct TextReplacement: Codable, Equatable, Hashable, Sendable {
  public var heard: String
  public var replacement: String
  public init(heard: String, replacement: String) {
    self.heard = heard
    self.replacement = replacement
  }
}

/// Spellings applied to recognised words before speaker alignment.
/// Dictionary terms fix capitalisation, spacing and hyphenation of the same
/// letters; replacements rewrite phrases the model consistently mishears.
public struct TranscriptCorrections: Codable, Equatable, Sendable {
  public var dictionary: [String]
  public var replacements: [TextReplacement]

  public init(dictionary: [String] = [], replacements: [TextReplacement] = []) {
    self.dictionary = dictionary
    self.replacements = replacements
  }

  public var isEmpty: Bool { dictionary.isEmpty && replacements.isEmpty }

  /// Rewrites words in a single left-to-right pass, so corrected text is never
  /// corrected again. At each word the longest match wins; on equal length an
  /// explicit replacement wins over a dictionary term. A match spans the first
  /// word's start to the last word's end and keeps their outer punctuation.
  public func apply(to words: [TimedWord]) -> [TimedWord] {
    let rules = replacements.compactMap { rule -> (heard: [String], replacement: String)? in
      let heard = rule.heard.split(whereSeparator: \.isWhitespace).map {
        Self.fold(Self.parts(String($0)).core)
      }
      let replacement = rule.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !heard.isEmpty, !heard.contains(""), !replacement.isEmpty else { return nil }
      return (heard, replacement)
    }
    let terms = dictionary.compactMap { term -> (key: String, text: String)? in
      let text = term.trimmingCharacters(in: .whitespacesAndNewlines)
      let key = Self.spellingKey(text)
      return key.isEmpty ? nil : (key, text)
    }
    guard !rules.isEmpty || !terms.isEmpty else { return words }
    let parts = words.map { Self.parts($0.text) }
    var output: [TimedWord] = []
    var index = 0
    while index < words.count {
      var best: (count: Int, text: String)?
      for rule in rules where rule.heard.count > (best?.count ?? 0) {
        if matches(
          rule.heard.count, at: index, in: parts,
          where: { offset, part in
            Self.fold(part.core) == rule.heard[offset]
          })
        {
          best = (rule.heard.count, rule.replacement)
        }
      }
      for term in terms {
        guard let count = dictionaryMatch(term.key, at: index, in: parts),
          count > (best?.count ?? 0)
        else { continue }
        best = (count, term.text)
      }
      guard let best else {
        output.append(words[index])
        index += 1
        continue
      }
      let last = index + best.count - 1
      output.append(
        TimedWord(
          text: parts[index].leading + best.text + parts[last].trailing,
          start: words[index].start, end: max(words[index].end, words[last].end)))
      index += best.count
    }
    return output
  }

  /// Spoken words separated only by spaces; punctuation between them ends a phrase.
  private func matches(
    _ count: Int, at index: Int, in parts: [Parts],
    where predicate: (Int, Parts) -> Bool
  ) -> Bool {
    guard index + count <= parts.count else { return false }
    for offset in 0..<count {
      let part = parts[index + offset]
      if part.core.isEmpty || !predicate(offset, part) { return false }
      if offset > 0, !part.leading.isEmpty { return false }
      if offset < count - 1, !part.trailing.isEmpty { return false }
    }
    return true
  }

  private func dictionaryMatch(_ key: String, at index: Int, in parts: [Parts]) -> Int? {
    var joined = ""
    var count = 0
    while index + count < parts.count {
      let part = parts[index + count]
      let piece = Self.spellingKey(part.core)
      if piece.isEmpty || (count > 0 && !part.leading.isEmpty) { return nil }
      joined += piece
      count += 1
      if joined == key { return count }
      if !key.hasPrefix(joined) || !part.trailing.isEmpty { return nil }
    }
    return nil
  }

  private struct Parts {
    var leading: String
    var core: String
    var trailing: String
  }

  private static func parts(_ text: String) -> Parts {
    let scalars = Array(text.unicodeScalars)
    let isPunctuation = { (scalar: Unicode.Scalar) in
      CharacterSet.punctuationCharacters.contains(scalar)
    }
    let start = scalars.firstIndex { !isPunctuation($0) } ?? scalars.count
    let end = (scalars.lastIndex { !isPunctuation($0) } ?? -1) + 1
    let slice = { (range: Range<Int>) in
      String(String.UnicodeScalarView(scalars[range]))
    }
    guard start < end else { return Parts(leading: text, core: "", trailing: "") }
    return Parts(
      leading: slice(0..<start), core: slice(start..<end), trailing: slice(end..<scalars.count))
  }

  private static func fold(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }

  /// Letters and digits only, so "Fluid Audio", "fluid-audio" and "FluidAudio" agree.
  public static func spellingKey(_ text: String) -> String {
    String(
      String.UnicodeScalarView(
        fold(text).unicodeScalars.filter {
          CharacterSet.alphanumerics.contains($0)
        }))
  }
}
