import SwiftUI
import AppKit
private struct SummaryActivityIcon: View {
  let isAnimating: Bool

  var body: some View {
    Group {
      if #available(macOS 26, *) {
        if isAnimating {
          DrawingSummarySymbol()
        } else {
          Image(systemName: "text.line.2.summary")
        }
      } else {
        Image(systemName: "text.alignleft")
      }
    }
    .font(.system(size: 16, weight: .regular))
    .foregroundStyle(Color(nsColor: .systemGray))
  }
}

@available(macOS 26, *)
private struct DrawingSummarySymbol: View {
  // Draw On's active state is hidden; drawing occurs when it becomes inactive.
  @State private var isHidden = true

  var body: some View {
    Image(systemName: "text.line.2.summary")
      .symbolEffect(.drawOn.byLayer, options: .nonRepeating, isActive: isHidden)
      .task {
        do {
          // Let the initial hidden state mount before drawing the symbol on.
          try await Task.sleep(for: .milliseconds(50))
          while !Task.isCancelled {
            isHidden = false
            try await Task.sleep(for: .seconds(1.8))
            isHidden = true
            try await Task.sleep(for: .milliseconds(800))
          }
        } catch {
          // Removing the loading view cancels this cycle.
        }
      }
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
private let host = NSHostingView(rootView: HStack {
  SummaryActivityIcon(isAnimating: true).frame(width: 32, height: 32)
  Text("Summarizing…")
}.padding(20).frame(width: 250, height: 90).background(.white))
let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 250, height: 90), styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = host
window.orderFrontRegardless()
for (index, delay) in [0.3, 0.8, 1.4, 2.2, 3.1, 4.0].enumerated() {
  DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
    let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: bitmap)
    try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/summary-motion-\(index).png"))
  }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) { app.terminate(nil) }
app.run()
