import SwiftUI
import AppKit

@main struct Preview {
  @MainActor static func main() throws {
    let text = Text("For ") + Text("the").foregroundColor(.black).customAttribute(FindHighlight(selected: true)) + Text(" selected result, and ") + Text("the").foregroundColor(.black).customAttribute(FindHighlight(selected: false)) + Text(" other match.")
    let view = text.font(.system(size: 16)).textRenderer(FindHighlightRenderer())
      .padding(24).frame(width: 500, height: 90).background(Color(white: 0.78))
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) else { return }
    try data.write(to: URL(fileURLWithPath: "/tmp/minutes-highlight-preview.png"))
  }
}
