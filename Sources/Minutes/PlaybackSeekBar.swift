import AppKit
import SwiftUI

/// Native slider interaction and accessibility with Music's thumb-free progress track.
struct PlaybackSeekBar: NSViewRepresentable {
  var position: Double
  var duration: Double
  var enabled: Bool
  var expanded: Bool
  var seek: (Double) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeCoordinator() -> Coordinator { Coordinator(seek: seek) }

  func makeNSView(context: Context) -> NSSlider {
    let slider = NSSlider()
    slider.cell = PlaybackSeekCell()
    slider.sliderType = .linear
    slider.isContinuous = true
    slider.target = context.coordinator
    slider.action = #selector(Coordinator.changed(_:))
    slider.setAccessibilityLabel("Playback position")
    slider.toolTip = "Click or drag to seek"
    return slider
  }

  func updateNSView(_ slider: NSSlider, context: Context) {
    context.coordinator.seek = seek
    slider.minValue = 0
    slider.maxValue = max(1, duration)
    slider.doubleValue = min(max(0, position), slider.maxValue)
    slider.isEnabled = enabled && duration > 0
    context.coordinator.setTrackHeight(expanded ? 9 : 5, on: slider, animated: !reduceMotion)
    slider.needsDisplay = true
  }

  static func dismantleNSView(_ slider: NSSlider, coordinator: Coordinator) {
    coordinator.animationTask?.cancel()
  }

  @MainActor final class Coordinator: NSObject {
    var seek: (Double) -> Void
    var animationTask: Task<Void, Never>?
    private var targetHeight: CGFloat?

    init(seek: @escaping (Double) -> Void) { self.seek = seek }

    func setTrackHeight(_ height: CGFloat, on slider: NSSlider, animated: Bool) {
      guard let cell = slider.cell as? PlaybackSeekCell else { return }
      guard targetHeight != height || !animated else { return }
      animationTask?.cancel()
      let isInitial = targetHeight == nil
      targetHeight = height
      guard animated, !isInitial else {
        cell.trackHeight = height
        slider.needsDisplay = true
        return
      }
      let startHeight = cell.trackHeight
      let started = ProcessInfo.processInfo.systemUptime
      animationTask = Task { [weak slider] in
        while !Task.isCancelled {
          guard let slider else { return }
          let progress = min(1, (ProcessInfo.processInfo.systemUptime - started) / 0.18)
          let eased = progress * progress * (3 - 2 * progress)
          cell.trackHeight = startHeight + (height - startHeight) * eased
          slider.needsDisplay = true
          if progress == 1 { return }
          do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
        }
      }
    }

    @objc func changed(_ sender: NSSlider) { seek(sender.doubleValue) }
  }
}

private final class PlaybackSeekCell: NSSliderCell {
  var trackHeight: CGFloat = 5
  override func drawKnob(_ knobRect: NSRect) {}

  override func drawBar(inside rect: NSRect, flipped: Bool) {
    let track = NSRect(
      x: rect.minX, y: rect.midY - trackHeight / 2, width: rect.width, height: trackHeight)
    let outline = NSBezierPath(
      roundedRect: track, xRadius: trackHeight / 2, yRadius: trackHeight / 2)
    NSColor.quaternaryLabelColor.setFill()
    outline.fill()
    let fraction = maxValue > minValue ? (doubleValue - minValue) / (maxValue - minValue) : 0
    NSGraphicsContext.saveGraphicsState()
    outline.addClip()
    NSColor.secondaryLabelColor.withAlphaComponent(isEnabled ? 1 : 0.35).setFill()
    NSRect(
      x: track.minX, y: track.minY, width: track.width * min(1, max(0, fraction)),
      height: track.height
    ).fill()
    NSGraphicsContext.restoreGraphicsState()
  }
}
