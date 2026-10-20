import AppKit
import SwiftUI

@MainActor
private final class MeterFixture: ObservableObject {
  @Published var levels = RecordingLevels()
}

private struct MeterMotion: View {
  @ObservedObject var fixture: MeterFixture
  var body: some View {
    RecordingView(levels: fixture.levels)
      .frame(width: 620, height: 650)
      .background(Color(nsColor: .windowBackgroundColor))
      .environment(\.colorScheme, .dark)
  }
}

@main
struct MotionPreview {
  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let fixture = MeterFixture()
    let host = NSHostingView(rootView: MeterMotion(fixture: fixture))
    let window = NSWindow(
      contentRect: NSRect(x: 80, y: 80, width: 620, height: 650), styleMask: [.borderless],
      backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.contentView = host
    window.orderFrontRegardless()
    for (name, delay) in [("waiting", 0.2), ("moving", 0.54), ("signal", 0.75), ("quiet", 1.3)] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try! bitmap.representation(using: .png, properties: [:])!.write(
          to: URL(fileURLWithPath: "verification/recording-meters/\(name).png"))
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      fixture.levels = .init(
        microphone: .init(decibels: -4, peak: 1, receivedAt: .now),
        system: .init(decibels: -24, peak: 0.2, receivedAt: .now))
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      fixture.levels = .init(
        microphone: .init(decibels: -60, peak: 0, receivedAt: .now),
        system: .init(decibels: -60, peak: 0, receivedAt: .now))
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { app.terminate(nil) }
    app.run()
  }
}
