# Acoustic vocabulary boosting spike (2026-10-20)

Historical experiment: removed from Minutes on 2026-10-20 after real use showed
aggressive substitutions of unrelated phrases. The results below describe the
original spike, not the current transcription pipeline. Its implementation and
boost-specific tests have been removed; deterministic spelling corrections and
explicit replacements remain.

## Verdict

**Positive, as an opt-in.** FluidAudio 0.17.5's CTC vocabulary rescoring fixes mishearings that deterministic Replacements could not predict, such as Superbase, Akanjo/Akonjo and Zatelkaston/Zatelkastin/Zatelkuston. The timings of all other words are unchanged. With FluidAudio's similarity gate (0.52, raised to 0.55 for more than 10 terms) it also rewrote an ordinary word into an unspoken dictionary term. Minutes raises the gate to 0.60. In every measured run this removed all false replacements and kept every true correction.

The evidence comes from synthesized speech: two `say` voices, 12 terms and about 7 minutes of audio. It is enough to justify an opt-in, not to promise accuracy on real meetings. See Limits.

## Questions

### 1. Model cost and lifetime

- `CtcModels.downloadAndLoad` fetches `FluidInference/parakeet-ctc-110m-coreml`: 102 MB of files, 115 MB on disk. That includes `tokenizer.json`, which term tokenization needs. A cold download and load took 46 s on this connection; a warm load takes 0.4–0.7 s.
- The model is stored next to the other Minutes models in `~/Library/Application Support/Minutes/Models/parakeet-ctc-110m-coreml`.
- `TranscriptionService` holds an optional `CtcModels`, loaded only when a transcription passes `boostTerms`. `unload()` releases it, so `AppModel.scheduleModelUnload` and **Unload models** need no change. `isLoaded` still tracks only the ASR and speaker models, so a meeting without boosting never waits on or downloads the CTC model.
- Pitfall: `VocabularyBoostingSession.init` reads the tokenizer from `CtcModels.defaultCacheDirectory` (`~/Library/Application Support/FluidAudio/Models/...`), not from where the models were loaded. Minutes therefore does not use the session. `VocabularyBooster` tokenizes terms with `CtcTokenizer.load(from:)` from the Minutes directory and builds the public `CtcKeywordSpotter` and `VocabularyRescorer` directly.

### 2. Hour-long tracks without loading the track

Yes. `spotKeywordsWithLogProbs` needs a `[Float]` buffer, and its log probabilities are about 1,500 × 1,025 floats per minute: about 6 MB per minute, or 370 MB per hour if done in one pass. `VocabularyBooster` instead:

- opens the track with `AudioSourceFactory.makeDiskBackedSource`, the same memory-mapped 16 kHz source `transcribeDiskBacked` uses;
- splits the ASR tokens into windows of at most 60 s, cutting before the word with the longest preceding pause in each window's second half, so a term is never split;
- reads only that window's audio (padded 1 s before and 2 s after) and rescores it with window-local token timings, as FluidAudio documents for segments.

At most one window of audio and log probabilities, about 10 MB, is held at once. On the ~2.3 minute tracks (3 windows; the ASR used the disk-backed path above 30 s), the process footprint stayed flat: 63→66, 70→66 and 73→65 MB before and after boosting. Boosting took 6.5–11.7 s per 135–141 s of audio. That projects to roughly 3–5 extra minutes per hour of audio, measured on Core ML with the cpuAndNeuralEngine units. An hour-long run was not measured.

### 3. Mapping back onto `[TimedWord]`

Yes. `VocabularyRescorer.ctcTokenEvaluateCandidates` is public and leaves the transcript untouched. It returns every candidate with `legacyOutcome`, `canonicalTerm`, `wordRange`, `tokenRange`, and `startTime`/`endTime` on the supplied token clock. `VocabularyBooster.apply` takes candidates whose outcome is `.applied`, shifts them back by the window offset, and replaces the run of `TimedWord`s that start inside each span with one word: the term, spanning the run's first start to last end and keeping its trailing punctuation. Two-word runs work (`tail scale` → `Tailscale`). Every boosted word start is an original word start (asserted in each smoke run). The end-to-end test shows identical utterance speakers and start times with and without boosting. Boosting runs before speaker alignment, and on the Vocabulary branch it should run before `TranscriptCorrections.apply`, so explicit Replacements still win.

### 4. Does it improve recognition?

`Tests/MinutesTests/VocabularyBoostSmokeTests.swift`, opt-in with `MINUTES_INFERENCE_SMOKE=1`, uses this dictionary: Siobhan, Kubernetes, Grafana, Tailscale, Supabase, Pydantic, Okonjo, Zettelkasten, Nguyen, Kafka, Terraform, Saoirse. Terraform and Saoirse are never spoken. The passages are:

- **terms**: 5 sentences that use the first 10 terms;
- **control**: an ordinary meeting with near-collisions (store, sync the graph, tail the logs, storefront) and no terms;
- **long**: control and terms alternated three times (~2.3 min).

"Spoken terms found" counts distinct spoken terms present in the text, ignoring case.

| Voice / passage | Baseline found | FluidAudio default (effective 0.55 for 12 terms) | Minutes (0.60) |
| --- | --- | --- | --- |
| Samantha terms | 5/10 | 8/10, 1 false replacement | 8/10, 0 false |
| Samantha control | – | 1 false replacement | 0 |
| Samantha long | 6/10 | 9/10, 6 false of 17 | 9/10, 0 false of 11 |
| Daniel terms | 6/10 | 9/10, 1 false | 9/10, 0 false |
| Daniel control | – | 1 false | 0 |
| Daniel long | 6/10 | 9/10, 6 false of 15 | 9/10, 0 false of 9 |

- Every false replacement was `store` → `Saoirse` at similarity 0.571, from the `termCentricSingleWord` path. FluidAudio's documented over-fire controls (rescue floors 0.30/0.50 with cbw taper pivot 5, or `spotterRescueEnabled: false`) produced identical output, because they only govern the spotter-rescue path.
- Every true correction scored 0.667–1.0. The 0.60 gate sits between them, which is why `VocabularyBooster.minimumSimilarity` is 0.60.
- Not recovered: Siobhan heard as Chivan/Shavan/Shavorn, and Nguyen heard as Win (Daniel's voice got Nguyen right). These spellings are too far from the sound for a similarity gate. That is the case the deterministic Replacements are for (`Chivan` → `Siobhan`).
- Tailscale is already found ignoring case. Boosting corrected its spelling (`tail scale` → `Tailscale`) in the long Samantha run.

The end-to-end test `transcriptionBoostsDictionaryTermsEndToEnd` runs `TranscriptionService.transcribe` with and without `boostTerms`. With boosting it gains Zettelkasten, Supabase and Okonjo, produces no Saoirse, keeps identical speakers and starts, and `unload()` leaves `isLoaded` false.

## Implementation (uncommitted)

- `Sources/Minutes/VocabularyBoost.swift`: `VocabularyBooster` (term tokenization, windowed rescoring, the pure `windows` and `apply`).
- `Sources/Minutes/TranscriptionService.swift`: `transcribe(_:options:boostTerms:progress:)`. Empty `boostTerms` (the default) is exactly the old path and never touches the CTC model. A model load failure throws a message that says how to turn boosting off, rather than silently transcribing without it.
- `Tests/MinutesTests/VocabularyBoostTests.swift`: focused tests for replacement mapping and windowing (run by default).
- `Tests/MinutesTests/VocabularyBoostSmokeTests.swift`: the probe matrix and the end-to-end test (opt-in).

Not done here: the user-facing setting. The term source, `TranscriptCorrections.dictionary`, exists only in the uncommitted Vocabulary-tab branch (`claude/text-replacements-dictionary-1b3449`). Wiring it there takes three changes:

1. `AppModel`: `var vocabularyBoosting: Bool`, persisted as `vocabularyBoosting`, default `false`.
2. In the regenerate/transcribe call: `boostTerms: vocabularyBoosting ? corrections.dictionary : []`. In `TranscriptionService`, boost the raw words before `corrections.apply`.
3. A Vocabulary tab toggle, "Improve recognition of dictionary words", with a description that it downloads a 100 MB English model and adds a few minutes per hour of audio.

## Limits

- Synthesized speech from two macOS voices only. Real meetings (accents, crosstalk, compressed browser audio) are unmeasured, and the 0.60 gate was chosen from this small sample.
- The CTC model is English; its tokenizer will mangle or drop terms in other scripts. Parakeet v3 itself is multilingual.
- Larger dictionaries raise the false-replacement risk. FluidAudio raises its own floor to 0.55 above 10 terms and 0.60 above 100 (`ContextBiasingConstants.rescorerConfig`), and the stricter floor applies. Only 12 terms were tested.
- FluidAudio skips terms shorter than 3 characters.
- A term is never split across windows, but a phrase spoken across a pause of more than about 30 s could be.
- An hour-long run, peak (rather than before/after) memory, and the cold download inside the app UI were not measured.

## Commands

```sh
bash scripts/swift-local.sh test --filter 'boostReplaces|boostWindows'
MINUTES_INFERENCE_SMOKE=1 bash scripts/swift-local.sh test --filter 'vocabularyBoostingProbe|transcriptionBoostsDictionaryTermsEndToEnd'
```

Set `MINUTES_BOOST_VOICES=Samantha,Daniel` (the default) to choose voices for the probe.
