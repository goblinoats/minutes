# Capture file-position crash (2026-10-19)

## Evidence and scope

The supplied Minutes 0.1.1 report on macOS 26.6.2 shows an uncaught Objective-C exception in `AVAudioFile.framePosition`, called by `AudioSink.consume` on the microphone callback queue, terminating with SIGABRT. Swift `do/catch` does not catch that exception.

The original hardware/OS trigger remains unconfirmed. On this development host (macOS 27.0.1), normal reads of writer position succeeded across 16 PCM format/channel/interleaving combinations, and closing a writer produced a recoverable write error instead of an abort.

## Reproduction and patch

`captureDoesNotQueryWriterPosition` injects the reported failure through an AVAudioFile subclass whose position getter raises an Objective-C exception. Before the patch, running this test alone terminated with signal 6 in `AudioSink.consume`. This reproduces the exception path, not the original environmental cause.

The sink now counts successfully written frames independently for each track, including inserted silence. It no longer calls the writer position getter. The same test passes after the patch and verifies actual CAF samples, a multi-buffer silent gap, a subsequent contiguous write, and independent track offsets/lengths.

`closedCaptureWriterFailsWithoutAborting` also verifies a real write failure remains recoverable and leaves the partial CAF and tracks.json available.

## Verification

- Five focused capture tests pass after the patch.
- Full `bash scripts/swift-local.sh test` passes; five optional model/inference diagnostics are skipped.
- Strict swift-format lint on changed Swift files and `git diff --check` pass.
- The sample verification handles short reads: this host returned 79,872 frames for an 80,000-frame request; the remaining frames were present on the next read.
- Live microphone/browser capture on the reported OS/device remains unverified. No installed application or user recordings were changed.

Focused command:

```sh
bash scripts/swift-local.sh test --filter 'captureDoesNotQueryWriterPosition|closedCaptureWriterFailsWithoutAborting|capturePreservesSilenceAndTrackOffsets|tapPCMAndMicrophoneUseSharedHostTimeline|emptyCaptureFailsExplicitly'
```

Debug packaging (`bash scripts/build-app.sh debug`) and `codesign --verify --deep --strict dist/Minutes.app` also pass. The patched bundle is at `dist/Minutes.app`; it was not installed or launched.
