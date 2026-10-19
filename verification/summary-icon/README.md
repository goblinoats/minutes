# Mail-style summary icon comparison

Superseded: the app now uses the native `text.line.2.summary` SF Symbol and its Draw On effect. These images document the earlier custom reconstruction only.

2026-10-19. Reference: user-provided Apple Mail screenshot.

- `comparison-labels.png`: original Mail and Minutes screenshots beside a SwiftUI ImageRenderer render of the revised glyph and existing Minutes label (2x scale, system gray, 13-point bold text).
- `comparison.png`: aligned 32-pixel icon crops, enlarged 8x with nearest-neighbor scaling to expose raster contours, plus the same crops at their original 2x screenshot size. Before and refined icons are rendered from the production SummarySymbol path; Mail is cropped from the reference screenshot.
- `mail-reference-icon.png` and `refined-icon.png`: comparison inputs, without enlargement.

The production path now uses a 1.25-point round stroke, a circular cubic bend, a smaller rounded arrowhead, and adjusted line proportions. A 0.75-point optical offset aligns the shorter glyph with the existing text. Label font and spacing are unchanged. The draw-through animation uses the same revised path and retains its previous timing and Reduce Motion behavior.

Verification: inspected both comparison renders; idle and animated shaft/head overlap containment checks passed; debug packaging, strict code signature, Swift formatting and diff checks passed. This is a close reconstruction from the supplied raster reference, not Apple's original vector. Live animation and running-app appearance were not exercised; app not restarted.
