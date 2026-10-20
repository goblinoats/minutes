import Foundation
import Testing

@testable import MinutesCore

private func words(_ text: String) -> [TimedWord] {
  text.split(separator: " ").enumerated().map {
    TimedWord(text: String($1), start: Double($0), end: Double($0) + 0.5)
  }
}

@Test func dictionaryFixesCaseSpacingAndHyphensWithoutLosingTimings() {
  let corrections = TranscriptCorrections(dictionary: ["FluidAudio", " OpenAI ", "Node.js"])
  let result = corrections.apply(to: words("We use fluid audio, Open-AI and node js."))
  #expect(result.map(\.text) == ["We", "use", "FluidAudio,", "OpenAI", "and", "Node.js."])
  #expect(result[2] == TimedWord(text: "FluidAudio,", start: 2, end: 3.5))
  #expect(result[3] == TimedWord(text: "OpenAI", start: 4, end: 4.5))
  #expect(result[5] == TimedWord(text: "Node.js.", start: 6, end: 7.5))
}

@Test func replacementsMatchWholePhrasesIgnoringCaseAndKeepOuterPunctuation() {
  let corrections = TranscriptCorrections(replacements: [
    .init(heard: "cube control", replacement: "kubectl"),
    .init(heard: "jack", replacement: "Jaques"),
  ])
  let result = corrections.apply(to: words("(Cube Control) runs. Jackson asked jack?"))
  #expect(result.map(\.text) == ["(kubectl)", "runs.", "Jackson", "asked", "Jaques?"])
  #expect(result[0] == TimedWord(text: "(kubectl)", start: 0, end: 1.5))
}

@Test func dictionaryDoesNotReplaceSimilarSoundingWords() {
  let corrections = TranscriptCorrections(dictionary: ["Supabase", "Okonjo", "Terraform"])
  let input = words("Superbase and Akanjo discussed terra form.")
  let result = corrections.apply(to: input)
  #expect(result.map(\.text) == ["Superbase", "and", "Akanjo", "discussed", "Terraform."])
  #expect(Array(result.prefix(4)) == Array(input.prefix(4)))
  #expect(result[4] == TimedWord(text: "Terraform.", start: 4, end: 5.5))
}

@Test func punctuationBetweenWordsEndsAPhrase() {
  let corrections = TranscriptCorrections(
    dictionary: ["FluidAudio"], replacements: [.init(heard: "cube control", replacement: "kubectl")]
  )
  let text = "fluid. audio cube, control"
  #expect(
    corrections.apply(to: words(text)).map(\.text) == text.split(separator: " ").map(String.init))
}

@Test func longestMatchWinsAndReplacementsBeatEqualDictionaryMatches() {
  let corrections = TranscriptCorrections(
    dictionary: ["Minutes"],
    replacements: [
      .init(heard: "minutes", replacement: "Minutes app"),
      .init(heard: "minutes app store", replacement: "Mac App Store"),
    ])
  #expect(
    corrections.apply(to: words("minutes and minutes app store")).map(\.text)
      == ["Minutes app", "and", "Mac App Store"])
}

@Test func correctedTextIsNotCorrectedAgainAndEmptyRulesAreIgnored() {
  let corrections = TranscriptCorrections(
    dictionary: [" ", "..."],
    replacements: [
      .init(heard: "jack", replacement: "Jack Douglas"),
      .init(heard: "douglas", replacement: "Doug"),
      .init(heard: " ", replacement: "x"),
      .init(heard: "empty", replacement: " "),
    ])
  #expect(
    corrections.apply(to: words("jack douglas empty")).map(\.text)
      == ["Jack Douglas", "Doug", "empty"])
  let input = words("Résumé ... ok")
  #expect(TranscriptCorrections().apply(to: input) == input)
}

@Test func matchingIgnoresDiacritics() {
  let corrections = TranscriptCorrections(dictionary: ["Zoë"])
  #expect(corrections.apply(to: words("zoe said")).map(\.text) == ["Zoë", "said"])
}

@Test func correctionsRoundTripThroughJSON() throws {
  let corrections = TranscriptCorrections(
    dictionary: ["FluidAudio"], replacements: [.init(heard: "cube control", replacement: "kubectl")]
  )
  let data = try JSONEncoder().encode(corrections)
  #expect(try JSONDecoder().decode(TranscriptCorrections.self, from: data) == corrections)
}
