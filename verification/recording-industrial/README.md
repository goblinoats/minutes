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

## Native integration follow-up

Checkpoint `f5b1d51` preserves the ivory hardware treatment before this pass.

- Removed branding, the meeting-recorder subtitle, privacy claim, elapsed heading,
  visible stop caption, and transcription explainer. Retained useful input names,
  signal states, level readings, timer, and accessible stop label/help.
- Replaced the textured ivory enclosure and screws with an appearance-aware native
  control surface. Retained the grille, analog dial faces and orange transport.
- Shared start/stop button feedback: shallow hover travel and deeper pressed travel,
  with non-motion feedback when Reduce Motion is enabled.
- Moved high-frequency level observation out of ContentView into LiveRecordingView.
  Previously every level assignment invalidated the parent that constructs the
  NavigationSplitView and toolbar. This removes that source of recording-only
  toolbar churn; the user's precise live-resize symptom remains unconfirmed.
- Added quiet synthesized start/stop/completion cues and a Settings sound toggle.
  Start finishes before capture opens; stop plays after capture closes; completion
  plays after successful transcript persistence and export.

Verification for this pass:
- 47 focused capture/core regression checks passed, plus one audio-decoding test
  covering all three cues, their duration, amplitude and silent edges.
- Rendered and inspected the actual recorder in light, dark, compact and short
  configurations, plus synthetic meter updates.
- The accessibility interaction probe currently returns only an empty host AXGroup.
  Recompiling the same probe against the unchanged f5b1d51 RecordingView produces
  the same failure. Therefore its previous successful result is not fresh proof
  of stop activation in this pass. No workaround or passing claim is inferred.
- No live recording was initiated, and no audible evaluation or full-suite run was
  performed. Sound timbre, real hover feel and the original resize symptom need
  live user review.
- Final debug package and strict code-signature verification passed. Reopened the
  exact dist/Minutes.app bundle after confirming the previous app was idle. The
  rebuilt native New Meeting screen exposes the new Start Recording button in
  its accessibility tree. The initial launch inspection timed out; a subsequent
  inspection confirmed the window and control. No recording was started.

## Contrasting finishes and grille depth

- Restored ivory in dark app appearance and charcoal in light app appearance.
  The recorder's local color scheme is inverted so semantic text and separators
  retain appropriate contrast; the surrounding app keeps its own appearance.
- Added shaded cavity gradients, upper occlusion and lower bevel highlights to
  the existing grille perforations without changing geometry or interaction.
- Inspected fresh light/dark SwiftUI renders. Compact, short and synthetic meter
  renders also generated. Debug packaging, strict signature verification,
  swift-format lint and git diff whitespace checks passed.
- The existing native accessibility probe still reports an empty host tree;
  no new live recording or interaction verification is claimed for this visual pass.

## Browse while recording and fixed transport bezel

- Sidebar selection remains enabled during capture. The live view is routed only
  when selection matches the active capture meeting; completed meetings retain
  their transcript view. A Show Recording toolbar action returns to capture.
- Mutation and playback guards remain in place during capture. The stop path still
  uses activeMeeting independently of library selection.
- The stop key's outer rings remain stationary. Only its inner face translates
  into the well on hover/press, with shading and reduced raised shadow. Native
  Start Recording remains unchanged.
- Built the debug app and verified its signature; focused audio/core regression
  tests and formatting passed. The actual key's three states were rendered by
  verification/recording-controls/render.sh. Live capture/navigation and pointer
  interaction have not been exercised in the running app for this pass.

## Inset press feedback and recording status pill

- The key face now scales to 0.985 on hover and 0.96 on press, with only half a
  point of downward travel on press. An upper inset edge darkens as it recedes;
  the outer rim stays fixed. Reduce Motion retains shading without movement.
- While another meeting is selected, a bottom status pill shows Recording and
  elapsed time. Clicking it returns to the active meeting. It replaces the
  temporary toolbar return button and uses a safe-area inset to avoid covering
  transcript content. Its timer updates locally, without meter observation.
- Debug build and strict signature verification passed. The controls render probe
  includes the actual status pill and the three key states. Live pointer/capture
  navigation is not exercised by this visual fixture.
