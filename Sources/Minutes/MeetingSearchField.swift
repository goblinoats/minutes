import AppKit
import MinutesCore
import SwiftUI

/// Native search field with mutually exclusive scopes in its magnifier menu.
struct MeetingSearchField: NSViewRepresentable {
  @Binding var text: String
  @Binding var scope: MeetingSearchScope

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> NSSearchField {
    let field = NSSearchField()
    field.placeholderString = "Search"
    field.setAccessibilityLabel("Search")
    field.controlSize = .large
    field.sendsSearchStringImmediately = true
    field.sendsWholeSearchString = false
    field.delegate = context.coordinator
    field.target = context.coordinator
    field.action = #selector(Coordinator.searchChanged(_:))
    let menu = NSMenu()
    for scope in MeetingSearchScope.allCases {
      let item = NSMenuItem(
        title: scope.title, action: #selector(Coordinator.changeScope(_:)), keyEquivalent: "")
      item.tag = scope.rawValue
      item.target = context.coordinator
      menu.addItem(item)
    }
    field.searchMenuTemplate = menu
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return field
  }

  func updateNSView(_ field: NSSearchField, context: Context) {
    context.coordinator.parent = self
    if field.stringValue != text { field.stringValue = text }
    field.toolTip =
      scope == .titles ? "Search meeting titles" : "Search meeting titles and transcripts"
    let menu = field.searchMenuTemplate
    for item in menu?.items ?? [] {
      item.state = item.tag == scope.rawValue ? .on : .off
    }
    field.searchMenuTemplate = menu
  }

  @MainActor
  final class Coordinator: NSObject, NSSearchFieldDelegate {
    var parent: MeetingSearchField
    init(_ parent: MeetingSearchField) { self.parent = parent }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSSearchField else { return }
      parent.text = field.stringValue
    }

    @objc func searchChanged(_ field: NSSearchField) {
      parent.text = field.stringValue
    }

    @objc func changeScope(_ item: NSMenuItem) {
      guard let scope = MeetingSearchScope(rawValue: item.tag) else { return }
      parent.scope = scope
      for option in item.menu?.items ?? [] {
        option.state = option.tag == scope.rawValue ? .on : .off
      }
    }
  }
}
