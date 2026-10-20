import AVFoundation
import FluidAudio
import Foundation
import MinutesCore
import Testing

@testable import Minutes

private let boostTerms = [
  "Siobhan", "Kubernetes", "Grafana", "Tailscale", "Supabase", "Pydantic", "Okonjo",
  "Zettelkasten", "Nguyen", "Kafka", "Terraform", "Saoirse",
]

private let boostPassages: [(name: String, text: String, spoken: [String])] = [
  (
    "terms",
    """
    Siobhan will move the staging cluster to Kubernetes next week. \
    The Grafana dashboards are only reachable over Tailscale for now. \
    We store the login sessions in Supabase and validate them with Pydantic. \
    Doctor Okonjo asked for the Zettelkasten notes before the review. \
    Nguyen thinks the Kafka consumer is dropping messages.
    """,
    [
      "Siobhan", "Kubernetes", "Grafana", "Tailscale", "Supabase", "Pydantic", "Okonjo",
      "Zettelkasten", "Nguyen", "Kafka",
    ]
  ),
  (
    "control",
    """
    Welcome to the project meeting. Today we need to discuss the launch schedule and the \
    customer feedback. We should store the backups in a safer place and sync the graph \
    before Friday. I will tail the logs, check the store front, and send a summary. \
    Most people want clear transcripts with speaker names, and the notes should be \
    exported automatically. Let us schedule a review for next Friday and test the app \
    with a small group first. Thank you for the update, see you soon.
    """,
    []
  ),
]

// About 2.5 minutes: longer than the 30 s disk-backed ASR threshold and the
// 60 s boosting window, so terms land in several windows.
private let longPassage = (
  name: "long",
  text: Array(repeating: [boostPassages[1].text, boostPassages[0].text], count: 3).flatMap { $0 }
    .joined(separator: " "),
  spoken: boostPassages[0].spoken
)

private let boostConfigs:
  [(name: String, config: VocabularyRescorer.Config, minSimilarity: Float)] =
    [
      ("fluid-default", .default, ContextBiasingConstants.defaultMinSimilarity),
      (
        "fluid-floors",
        .init(
          shortTermCbwTaperPivot: 5, spotterRescueMinSimilarity: 0.30,
          spotterRescueMultiWordMinSimilarity: 0.50),
        ContextBiasingConstants.defaultMinSimilarity
      ),
      (
        "no-rescue", .init(spotterRescueEnabled: false),
        ContextBiasingConstants.defaultMinSimilarity
      ),
      ("minutes", .default, VocabularyBooster.minimumSimilarity),
    ]

private func footprintMB() -> Int {
  var info = task_vm_info_data_t()
  var count = mach_msg_type_number_t(
    MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
  let result = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
      task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
    }
  }
  return result == KERN_SUCCESS ? Int(info.phys_footprint / 1_000_000) : -1
}

// Explicit opt-in: downloads the CTC model and measures boosting on synthesized
// speech, printing one line per voice, passage and rescorer configuration.
@Test(.enabled(if: ProcessInfo.processInfo.environment["MINUTES_INFERENCE_SMOKE"] == "1"))
func vocabularyBoostingProbe() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "minutes-boost-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let modelDirectory = await TranscriptionService().modelDirectory
  let asr = AsrManager(config: .default)
  try await asr.loadModels(
    try await AsrModels.downloadAndLoad(to: modelDirectory, version: .v3))
  let ctcDirectory = VocabularyBooster.modelDirectory(in: modelDirectory)
  let loadStart = Date()
  let ctc = try await CtcModels.downloadAndLoad(to: ctcDirectory)
  print("ctc load: \(String(format: "%.1f", Date().timeIntervalSince(loadStart))) s")

  func found(_ text: String, _ terms: [String]) -> Int {
    terms.filter { text.range(of: $0, options: .caseInsensitive) != nil }.count
  }
  let voices = (ProcessInfo.processInfo.environment["MINUTES_BOOST_VOICES"] ?? "Samantha,Daniel")
    .split(separator: ",").map(String.init)
  for voice in voices {
    for passage in boostPassages + [longPassage] {
      let audio = directory.appendingPathComponent("\(voice)-\(passage.name).aiff")
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
      process.arguments = ["-v", voice, "-r", "160", "-o", audio.path, passage.text]
      try process.run()
      process.waitUntilExit()
      #expect(process.terminationStatus == 0)
      var state = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
      let tokens = try #require(try await asr.transcribe(audio, decoderState: &state).tokenTimings)
      let words = try WordTiming.words(tokens)
      let before = words.map(\.text).joined(separator: " ")
      print("\n[\(voice) \(passage.name)] baseline: \(before)")
      for (name, config, minSimilarity) in boostConfigs {
        let booster = try #require(
          try await VocabularyBooster(
            terms: boostTerms, models: ctc, directory: ctcDirectory, config: config,
            minSimilarity: minSimilarity))
        let memoryBefore = footprintMB()
        let start = Date()
        let replacements = try await booster.replacements(tokens: tokens, audio: audio)
        let seconds = Date().timeIntervalSince(start)
        let boosted = VocabularyBooster.apply(replacements, to: words)
        let after = boosted.map(\.text).joined(separator: " ")
        let wrong = replacements.filter { !passage.spoken.contains($0.term) }
        print(
          "[\(voice) \(passage.name) \(name)] spoken terms found "
            + "\(found(before, passage.spoken))->\(found(after, passage.spoken))"
            + "/\(passage.spoken.count), replacements \(replacements.count), "
            + "unspoken-term replacements \(wrong.count), "
            + "\(String(format: "%.2f", seconds)) s for "
            + "\(String(format: "%.1f", words.last?.end ?? 0)) s audio, "
            + "\(VocabularyBooster.windows(tokens, maxSeconds: VocabularyBooster.windowSeconds).count) "
            + "window(s), footprint \(memoryBefore)->\(footprintMB()) MB")
        for replacement in replacements { print("    \(replacement.evidence)") }
        #expect(boosted.map(\.start) == boosted.map(\.start).sorted())
        #expect(Set(boosted.map(\.start)).isSubset(of: Set(words.map(\.start))))
      }
    }
  }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["MINUTES_INFERENCE_SMOKE"] == "1"))
func transcriptionBoostsDictionaryTermsEndToEnd() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "minutes-boost-e2e-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let audio = directory.appendingPathComponent("terms.aiff")
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
  process.arguments = [
    "-v", "Daniel", "-r", "160", "-o", audio.path,
    boostPassages[1].text + " " + boostPassages[0].text,
  ]
  try process.run()
  process.waitUntilExit()
  let tracks = AudioTracks(remote: audio, microphone: nil, remoteOffset: 0, microphoneOffset: 0)
  let service = TranscriptionService()
  let plain = try await service.transcribe(tracks) { _ in }
  let boosted = try await service.transcribe(tracks, boostTerms: boostTerms) { print($0) }
  let plainText = plain.map(\.text).joined(separator: " ")
  let boostedText = boosted.map(\.text).joined(separator: " ")
  print("plain:   \(plainText)\nboosted: \(boostedText)")
  #expect(!plainText.contains("Zettelkasten") && boostedText.contains("Zettelkasten"))
  #expect(boostedText.contains("Supabase") && boostedText.contains("Okonjo"))
  #expect(!boostedText.contains("Saoirse"))
  #expect(boosted.map(\.speaker) == plain.map(\.speaker))
  #expect(boosted.map(\.start) == plain.map(\.start))
  await service.unload()
  #expect(await !service.isLoaded)
}
