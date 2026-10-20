import SwiftUI

struct TranscriptFindActions {
  let show: () -> Void
  let next: () -> Void
  let previous: () -> Void
  let canGoNext: Bool
  let canGoPrevious: Bool
}

private struct TranscriptFindKey: FocusedValueKey {
  typealias Value = TranscriptFindActions
}

extension FocusedValues {
  var transcriptFind: TranscriptFindActions? {
    get { self[TranscriptFindKey.self] }
    set { self[TranscriptFindKey.self] = newValue }
  }
}

struct TranscriptFindCommands: Commands {
  @FocusedValue(\.transcriptFind) private var actions

  var body: some Commands {
    CommandGroup(after: .textEditing) {
      Menu("Find") {
        Button("Find…") { actions?.show() }
          .keyboardShortcut("f", modifiers: .command)
          .disabled(actions == nil)
        Button("Find Next") { actions?.next() }
          .keyboardShortcut("g", modifiers: .command)
          .disabled(actions?.canGoNext != true)
        Button("Find Previous") { actions?.previous() }
          .keyboardShortcut("g", modifiers: [.command, .shift])
          .disabled(actions?.canGoPrevious != true)
      }
    }
  }
}
