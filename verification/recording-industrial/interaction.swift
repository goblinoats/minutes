import AppKit
import SwiftUI

@MainActor private final class TransportFixture: ObservableObject {
  @Published var enabled = false
  var presses = 0
}

private struct TransportPreview: View {
  @ObservedObject var fixture: TransportFixture
  var body: some View {
    RecordingView(
      levels: .init(), startedAt: .now.addingTimeInterval(-83), canStop: fixture.enabled
    ) {
      fixture.presses += 1
    }
    .frame(width: 520, height: 400)
  }
}

@main struct TransportProbe {
  @MainActor static func elements(_ object: Any, depth: Int = 0) -> [AnyObject] {
    guard depth < 20 else { return [] }
    let item = object as AnyObject
    return [item]
      + ((item.accessibilityChildren?() ?? nil) ?? []).flatMap { elements($0, depth: depth + 1) }
  }

  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let fixture = TransportFixture()
    let host = NSHostingView(rootView: TransportPreview(fixture: fixture))
    let window = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 520, height: 400), styleMask: [.titled],
      backing: .buffered, defer: false)
    window.contentView = host
    window.makeKeyAndOrderFront(nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      let buttons = elements(host).filter { $0.accessibilityRole?() == .button }
      guard let button = buttons.first(where: { $0.accessibilityLabel?() == "Stop & Transcribe" })
      else {
        print("FAIL: Stop button missing from native accessibility tree")
        exit(1)
      }
      precondition(button.isAccessibilityEnabled?() == false)
      _ = button.accessibilityPerformPress?()
      precondition(fixture.presses == 0)
      print("PASS: disabled transport does not invoke stop")
      fixture.enabled = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      let button = elements(host).first {
        $0.accessibilityLabel?() == "Stop & Transcribe" && $0.accessibilityRole?() == .button
      }!
      precondition(button.isAccessibilityEnabled?() == true)
      precondition(button.accessibilityPerformPress?() == true)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
      precondition(fixture.presses == 1)
      print("PASS: enabled native transport invokes stop exactly once")
      app.terminate(nil)
    }
    app.run()
  }
}
