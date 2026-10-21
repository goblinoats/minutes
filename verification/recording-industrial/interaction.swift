import AppKit
import SwiftUI

@MainActor private final class TransportFixture: ObservableObject {
  @Published var enabled = false
  @Published var recording = true
  @Published var previewing = false
  var presses = 0
}

private struct TransportPreview: View {
  @ObservedObject var fixture: TransportFixture
  var body: some View {
    RecordingView(
      levels: .init(), isRecording: fixture.recording,
      startedAt: .now.addingTimeInterval(-83), canOperate: fixture.enabled,
      onTransport: { fixture.presses += 1 }, microphonePreview: $fixture.previewing
    ) {
      Text("Helium")
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

  /// SwiftUI publishes its accessibility tree lazily, so wait for the element
  /// rather than assuming a fixed delay.
  @MainActor static func whenFound(
    _ label: String, role: NSAccessibility.Role, in host: NSView, attempts: Int = 40,
    then body: @escaping (AnyObject) -> Void
  ) {
    if let element = elements(host).first(where: {
      $0.accessibilityRole?() == role && $0.accessibilityLabel?() == label
    }) {
      body(element)
    } else if attempts == 0 {
      print("FAIL: \(label) missing from native accessibility tree")
      exit(1)
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        whenFound(label, role: role, in: host, attempts: attempts - 1, then: body)
      }
    }
  }

  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let fixture = TransportFixture()
    let host = NSHostingView(rootView: TransportPreview(fixture: fixture))
    // SwiftUI vends its accessibility tree only for a key window. A nonactivating
    // panel becomes key without taking focus from the app the user is in.
    let window = NSPanel(
      contentRect: NSRect(x: 100, y: 100, width: 520, height: 400),
      styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
    window.contentView = host
    window.makeKeyAndOrderFront(nil)
    whenFound("Stop & Transcribe", role: .button, in: host) { button in
      precondition(button.isAccessibilityEnabled?() == false)
      _ = button.accessibilityPerformPress?()
      precondition(fixture.presses == 0)
      print("PASS: disabled transport does not invoke stop")
      fixture.enabled = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        whenFound("Stop & Transcribe", role: .button, in: host) { button in
          precondition(button.isAccessibilityEnabled?() == true)
          precondition(button.accessibilityPerformPress?() == true)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            precondition(fixture.presses == 1)
            print("PASS: enabled native transport invokes stop exactly once")
            fixture.recording = false
            checkReadyState(fixture, host: host, app: app)
          }
        }
      }
    }
    app.run()
  }

  @MainActor fileprivate static func checkReadyState(
    _ fixture: TransportFixture, host: NSView, app: NSApplication
  ) {
    whenFound("Start Recording", role: .button, in: host) { button in
      precondition(button.accessibilityPerformPress?() == true)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        precondition(fixture.presses == 2)
        print("PASS: the same key starts recording before capture")
        whenFound("Preview Level", role: .checkBox, in: host) { toggle in
          precondition(toggle.accessibilityPerformPress?() == true)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            precondition(fixture.previewing)
            print("PASS: microphone preview switch is a native toggle")
            app.terminate(nil)
          }
        }
      }
    }
  }
}
