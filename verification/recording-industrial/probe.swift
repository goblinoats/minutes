import AppKit
import SwiftUI

@main
struct RecordingPreview {
  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let configurations: [(String, CGFloat, CGFloat, ColorScheme)] = [
      ("light", 620, 650, .light), ("dark", 620, 650, .dark),
      ("compact", 320, 570, .dark), ("short", 520, 400, .light),
    ]
    var windows: [NSWindow] = []
    for (index, config) in configurations.enumerated() {
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6) {
        let (name, width, height, scheme) = config
        let levels = RecordingLevels(
          microphone: .init(decibels: -18, peak: 0.4, receivedAt: .now),
          system: .init(decibels: -32, peak: 0.2, receivedAt: .now))
        let host = NSHostingView(
          rootView:
            RecordingView(levels: levels, startedAt: Date.now.addingTimeInterval(-83))
            .frame(width: width, height: height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme))
        let window = NSWindow(
          contentRect: NSRect(x: 80, y: 80, width: width, height: height), styleMask: [.borderless],
          backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        window.orderFrontRegardless()
        windows.append(window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
          host.cacheDisplay(in: host.bounds, to: bitmap)
          try! bitmap.representation(using: .png, properties: [:])!.write(
            to: URL(fileURLWithPath: "verification/recording-industrial/\(name).png"))
          window.orderOut(nil)
        }
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { app.terminate(nil) }
    app.run()
  }
}
