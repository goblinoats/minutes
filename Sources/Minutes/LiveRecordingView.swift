import SwiftUI

/// Keep the 20 Hz observation inside this leaf. Reading levels in ContentView
/// also invalidates its NavigationSplitView and native toolbar during resizing.
struct LiveRecordingView: View {
  let model: AppModel

  var body: some View {
    RecordingView(
      levels: model.recordingLevels, startedAt: model.recordingStarted,
      canStop: !model.isBusy, onStop: { model.stop() }
    )
    .task {
      while !Task.isCancelled && model.isRecording {
        await model.refreshRecordingLevels()
        do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
      }
    }
  }
}
