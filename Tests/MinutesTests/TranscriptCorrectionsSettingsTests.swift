import Foundation
import MinutesCore
import Testing

@testable import Minutes

@Test @MainActor func transcriptCorrectionsPersistAndReplaceEquivalentEntries() throws {
  let suite = "MinutesTests.\(UUID().uuidString)"
  let preferences = try #require(UserDefaults(suiteName: suite))
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
  defer {
    preferences.removePersistentDomain(forName: suite)
    try? FileManager.default.removeItem(at: directory)
  }
  let model = AppModel(supportDirectory: directory, preferences: preferences)
  #expect(model.corrections.isEmpty)
  model.addDictionaryTerm("  Openai ")
  model.addDictionaryTerm("OpenAI")
  model.addDictionaryTerm("FluidAudio")
  model.addDictionaryTerm(" ")
  model.addDictionaryTerm("...")
  #expect(model.corrections.dictionary == ["FluidAudio", "OpenAI"])
  model.addReplacement(heard: " cube   control ", replacement: "kube control")
  model.addReplacement(heard: "Cube Control", replacement: " kubectl ")
  model.addReplacement(heard: "same", replacement: "same")
  model.addReplacement(heard: "missing", replacement: " ")
  #expect(model.corrections.replacements == [.init(heard: "Cube Control", replacement: "kubectl")])

  #expect(!model.vocabularyBoosting)
  model.vocabularyBoosting = true

  let reloaded = AppModel(supportDirectory: directory, preferences: preferences)
  #expect(reloaded.corrections == model.corrections)
  #expect(reloaded.vocabularyBoosting)
  reloaded.corrections.dictionary.removeAll { $0 == "OpenAI" }
  #expect(
    AppModel(supportDirectory: directory, preferences: preferences).corrections.dictionary
      == ["FluidAudio"])
}
