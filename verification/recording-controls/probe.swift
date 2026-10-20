// Appended to RecordingView.swift by render.sh to exercise its private key directly.
@main struct KeyPreview {
  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let host = NSHostingView(rootView:
      VStack(spacing: 24) {
      HStack(spacing: 36) {
        TransportKey(compact: false)
        TransportKey(compact: false, hovering: true)
        TransportKey(compact: false, pressed: true, hovering: true)
      }
      RecordingIndicator(startedAt: .now.addingTimeInterval(-83), showRecording: {})
      }.padding(32).background(Color(white: 0.2)).environment(\.colorScheme, .dark))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 346, height: 210), styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.contentView = host
    window.orderFrontRegardless()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "verification/recording-controls/states.png"))
      app.terminate(nil)
    }
    app.run()
  }
}
