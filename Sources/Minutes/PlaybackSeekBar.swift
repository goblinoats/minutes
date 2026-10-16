import SwiftUI

/// Music-style progress display: while the pointer is over the track, the label blurs away in
/// favor of elapsed and remaining time and the track thickens for scrubbing. Seeks glide the fill to the
/// new position instead of jumping.
struct PlaybackSeekBar<Label: View>: View {
  var position: Double
  var duration: Double
  var enabled: Bool
  var seek: (Double) -> Void
  @ViewBuilder var label: () -> Label

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ViewState private var hovering = false
  // Pointer-driven time while the track is pressed; the seek happens on release.
  @ViewState private var scrubTime: Double?
  // Drawn position, animated separately from the playback clock.
  @ViewState private var shownTime: Double = 0

  init(
    position: Double, duration: Double, enabled: Bool, seek: @escaping (Double) -> Void,
    @ViewBuilder label: @escaping () -> Label
  ) {
    self.position = position
    self.duration = duration
    self.enabled = enabled
    self.seek = seek
    self.label = label
  }

  private var isActive: Bool { enabled && duration > 0 }
  private var expanded: Bool { isActive && (hovering || scrubTime != nil) }

  var body: some View {
    let time = scrubTime ?? position
    VStack(alignment: .leading, spacing: 5) {
      ZStack(alignment: .bottomLeading) {
        label()
          .frame(maxWidth: .infinity, alignment: .leading)
          .blur(radius: expanded && !reduceMotion ? 6 : 0)
          .opacity(expanded ? 0 : 1)
        HStack {
          Text(Self.format(Int(time)))
          Spacer(minLength: 8)
          Text("\u{2212}" + Self.format(max(0, Int(duration) - Int(time))))
        }
        .font(.subheadline.monospacedDigit())
        .blur(radius: expanded || reduceMotion ? 0 : 6)
        .opacity(expanded ? 1 : 0)
        .accessibilityHidden(true)
      }
      track
    }
    .animation(
      reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.28), value: expanded
    )
    .onAppear { shownTime = position }
    .onChange(of: position) { _, new in
      if scrubTime == nil { show(new) }
    }
    .onChange(of: scrubTime) { _, new in
      if new == nil { show(position) }
    }
  }

  private var track: some View {
    GeometryReader { proxy in
      let height: CGFloat = expanded ? 8 : 4
      let fraction = duration > 0 ? min(1, max(0, shownTime / duration)) : 0
      ZStack(alignment: .leading) {
        Capsule().fill(Color.primary.opacity(expanded ? 0.16 : 0.1))
        Capsule().fill(Color.primary.opacity(expanded ? 0.85 : 0.45))
          .frame(width: max(height, proxy.size.width * fraction))
      }
      .frame(height: height)
      .clipShape(Capsule())
      .frame(maxHeight: .infinity)
      .opacity(isActive ? 1 : 0.5)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let width = max(1, proxy.size.width)
            let target = min(1, max(0, value.location.x / width)) * duration
            let pressed = scrubTime == nil
            scrubTime = target
            // The press glides to the pointer; dragging after that tracks it directly.
            if pressed { show(target) } else { shownTime = target }
          }
          .onEnded { _ in
            guard let target = scrubTime else { return }
            seek(target)
            scrubTime = nil
          },
        including: isActive ? .all : .none
      )
    }
    .frame(height: 12)
    .onHover { hovering = $0 }
    .help("Click or drag to seek")
    .accessibilityRepresentation {
      Slider(
        value: Binding(get: { position }, set: { seek($0) }), in: 0...max(1, duration)
      ) {
        Text("Playback position")
      }
      .accessibilityValue("\(Self.format(Int(position))) of \(Self.format(Int(duration)))")
      .disabled(!isActive)
    }
  }

  private func show(_ time: Double) {
    if reduceMotion {
      shownTime = time
    } else {
      // Clock ticks retarget the same curve, so playback progress stays continuous.
      withAnimation(.smooth(duration: 0.3)) { shownTime = time }
    }
  }

  static func format(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = seconds % 3600 / 60
    let secs = seconds % 60
    return hours > 0
      ? String(format: "%d:%02d:%02d", hours, minutes, secs)
      : String(format: "%d:%02d", minutes, secs)
  }
}
