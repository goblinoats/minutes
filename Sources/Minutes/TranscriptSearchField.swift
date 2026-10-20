import AppKit
import MinutesCore
import SwiftUI

struct TranscriptSearchField: NSViewRepresentable {
  @Binding var text: String
  @Binding var options: TranscriptSearch.Options
  let focusRequest: Int
  let next: () -> Void
  let previous: () -> Void
  let dismiss: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> FindField {
    let field = FindField()
    field.placeholderString = "Search transcript"
    field.setAccessibilityLabel("Search transcript")
    field.sendsSearchStringImmediately = true
    field.sendsWholeSearchString = false
    field.delegate = context.coordinator
    field.target = context.coordinator
    field.action = #selector(Coordinator.searchChanged(_:))
    field.searchMenuTemplate = context.coordinator.makeMenu()
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return field
  }

  func updateNSView(_ field: FindField, context: Context) {
    context.coordinator.parent = self
    context.coordinator.updateMenu(field.searchMenuTemplate)
    if field.stringValue != text { field.stringValue = text }
    if context.coordinator.focusRequest != focusRequest {
      context.coordinator.focusRequest = focusRequest
      field.window?.makeFirstResponder(field)
      field.selectText(nil)
    }
  }

  final class FindField: NSSearchField {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window else { return }
      window.makeFirstResponder(self)
      selectText(nil)
    }
  }

  @MainActor
  final class Coordinator: NSObject, NSSearchFieldDelegate {
    var parent: TranscriptSearchField
    var focusRequest: Int

    init(_ parent: TranscriptSearchField) {
      self.parent = parent
      self.focusRequest = parent.focusRequest
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSSearchField else { return }
      parent.text = field.stringValue
    }

    @objc func searchChanged(_ field: NSSearchField) {
      parent.text = field.stringValue
    }

    func makeMenu() -> NSMenu {
      let menu = NSMenu()
      for (title, tag) in [
        ("Ignore Case", 1), ("Wrap Around", 2), ("Contains", 3), ("Starts With", 4),
      ] {
        if tag == 3 { menu.addItem(.separator()) }
        let item = NSMenuItem(title: title, action: #selector(changeOption(_:)), keyEquivalent: "")
        item.tag = tag
        item.target = self
        menu.addItem(item)
      }
      updateMenu(menu)
      return menu
    }

    func updateMenu(_ menu: NSMenu?) {
      for item in menu?.items ?? [] {
        let checked: Bool
        switch item.tag {
        case 1: checked = parent.options.ignoreCase
        case 2: checked = parent.options.wrapAround
        case 3: checked = parent.options.mode == .contains
        case 4: checked = parent.options.mode == .startsWith
        default: continue
        }
        item.state = checked ? .on : .off
      }
    }

    @objc private func changeOption(_ item: NSMenuItem) {
      switch item.tag {
      case 1: parent.options.ignoreCase.toggle()
      case 2: parent.options.wrapAround.toggle()
      case 3: parent.options.mode = .contains
      case 4: parent.options.mode = .startsWith
      default: break
      }
      updateMenu(item.menu)
    }

    func control(
      _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
      if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
        parent.dismiss()
        return true
      }
      if commandSelector == #selector(NSResponder.insertNewline(_:)) {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
          parent.previous()
        } else {
          parent.next()
        }
        return true
      }
      return false
    }
  }
}
