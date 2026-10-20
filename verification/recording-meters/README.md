# Recording microphone and live meters — 2026-10-20

Replace the disabled new-meeting form during capture with a vector homage to the
original Voice Memos microphone and independent analogue microphone/system meters.
System audio means the selected browser and its helpers, as in the existing tap.

## Implementation checkpoints

1. Measure RMS dBFS and peak amplitude from successfully written PCM buffers on the
   existing serial capture queue. Test stereo, integer/interleaved audio, silence,
   stale readings, clipping, and independent tracks without changing retained audio.
2. Poll aggregated readings at 20 Hz while the recording view is mounted. Reset on
   start/stop, expire old readings after 0.5 seconds, and cancel polling on departure.
3. Render a native scalable microphone and two warm needle meters; retain the stop
   action and timer, include textual signal states and respect Reduce Motion.
4. Verify focused tests, actual SwiftUI renders in light/dark/compact layouts,
   debug packaging and signature. A live browser/microphone session is separate.

## Verification

- `bash scripts/swift-local.sh test --filter 'RecordingLevels|AudioCaptureTests|MinutesCoreTests|BrowserAudioTapTests|WordTiming'`: 47 tests passed (12 app tests and 35 core tests).
- Strict Swift formatting for all changed source/test files and `git diff --check` passed.
- `bash scripts/build-app.sh debug` and `codesign --verify --deep --strict dist/Minutes.app` passed.
- `probe.swift` compiles with the actual RecordingView and RecordingLevels sources; native light/dark, 320-point-wide and short-window snapshots are saved here. The narrow layout was revised after the first render placed the second meter below the viewport. Both meters and labels now fit.
- `motion.swift` renders the same view with synthetic readings: waiting, an intermediate needle position, distinct settled levels with clipping, and quiet. Snapshots demonstrate independent needle movement. These are component renders, not a live browser/microphone capture.
- Initial compile started before RecordingView had been created and failed with that missing type; subsequent compilation and all selected tests passed.
- Live browser/microphone input, full-app recording/stop interaction, VoiceOver and the full test suite were not exercised. The previous task identified unrelated Keychain-dependent fixtures in the full suite. The running app was not restarted.

The recognition removal was committed separately as `6027d7e`. This recording UI
increment was committed as checkpoint `0fa97fe`. The subsequent industrial design
refinement and its current render script live in `verification/recording-industrial`.

To reproduce these historical renders from the repository root at checkpoint `0fa97fe`:

```sh
xcrun swiftc Sources/Minutes/RecordingLevels.swift Sources/Minutes/RecordingView.swift verification/recording-meters/probe.swift -o /tmp/minutes-recording-preview
/tmp/minutes-recording-preview
xcrun swiftc Sources/Minutes/RecordingLevels.swift Sources/Minutes/RecordingView.swift verification/recording-meters/motion.swift -o /tmp/minutes-recording-motion
/tmp/minutes-recording-motion
```
