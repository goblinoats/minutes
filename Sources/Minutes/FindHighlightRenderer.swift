import SwiftUI

struct FindHighlight: TextAttribute {
  let selected: Bool
}

/// Draw the highlight separately from its glyphs so only the small white/yellow
/// backing gets a shadow, rather than blurring or shadowing the text itself.
struct FindHighlightRenderer: TextRenderer {
  func draw(layout: Text.Layout, in context: inout GraphicsContext) {
    for line in layout {
      for run in line {
        if let highlight = run[FindHighlight.self] {
          let rect = run.typographicBounds.rect.insetBy(dx: -0.5, dy: 0)
          var backing = context
          backing.addFilter(.shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 1))
          backing.fill(
            Path(rect),
            with: .color(
              highlight.selected
                ? Color(.sRGB, red: 1, green: 1, blue: 0, opacity: 1) : .white))
        }
        context.draw(run)
      }
    }
  }
}
