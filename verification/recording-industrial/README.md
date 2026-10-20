# Recording instrument refinement

Checkpoint: `0fa97fe` preserves the original microphone and independent live meters.

Use the app icon's ivory recorder as the material and proportion reference. Build
one coherent, usable recording instrument: a perforated microphone grille, quiet
screen-printed labels, orange recording lamp, recessed paired needle meters,
elapsed time, and a tactile Stop & Transcribe key. Keep the existing measurement
and capture pipeline. All decorative hardware is hidden from accessibility;
only the transport key acts as a button.

## Plan

- Refine the actual SwiftUI recording screen and integrate its existing transport.
- Preserve microphone/browser signal labels, true dBFS scale, reduced-motion
  behavior, and the busy guard on stopping capture.
- Render the actual component at light, dark, compact and short window sizes.
- Verify changing needle positions and quiet/clipping states with synthetic data.
- Check native keyboard/button behavior, compile, format, run focused regression
  tests, and package/verify the updated app.

Run `bash verification/recording-industrial/render.sh` to compile the actual
MinutesCore, RecordingLevels and RecordingView sources into isolated preview
programs. The preview fixture supplies synthetic input levels and elapsed time;
it does not capture a meeting or authenticate against the user's accounts.

## Verification

- 47 selected regression tests passed: 12 audio meter/capture/browser callback/word timing tests and all 35 MinutesCore tests.
- Strict formatting for changed app sources and `git diff --check` passed.
- Debug app packaged at `dist/Minutes.app`; strict codesign verification passed.
- Inspected actual SwiftUI light/dark, 320-point compact and 400-point-tall renders. The first short-window render hid the transport below the viewport; the final condensed layout preserves both meters, elapsed time and the stop key. The full grille appears when vertical room permits.
- Synthetic motion renders show independent moving/settled needles, waiting, quiet and clipping states. Darker orange text preserves the clipping label's contrast against ivory.
- Native accessibility activation found the real SwiftUI button with its Stop & Transcribe label, verified the disabled state does not invoke the action, and verified one enabled press invokes the closure exactly once.
- The interaction probe initially used the wrong AppKit protocol name, then excluded SwiftUI nodes that implement accessibility methods without declaring full protocol conformance. Traversing the native Objective-C accessibility methods fixed the probe. An intermediate probe compile was invalidated by a concurrent source edit; the final source compiled and passed.
- Not verified: live meeting capture, full-app stop/transcription, keyboard focus/Space interaction, VoiceOver narration, and the full test suite. No running app restart or installed-app replacement.

The design refinement remains uncommitted for review against checkpoint `0fa97fe`.
