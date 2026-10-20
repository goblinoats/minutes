import MinutesCore
import SwiftUI

/// Analog meters in a native, appearance-aware recording surface.
struct RecordingView: View {
  @Environment(\.colorScheme) private var colorScheme
  let levels: RecordingLevels
  var startedAt: Date? = nil
  var canStop = true
  var onStop: () -> Void = {}

  var body: some View {
    GeometryReader { geometry in
      let condensed = geometry.size.height < 500
      let compact = geometry.size.width < 440 || condensed
      ScrollView {
        VStack(spacing: 18) {
          instrument(compact: compact, condensed: condensed)
            .environment(\.colorScheme, colorScheme == .dark ? .light : .dark)
            .frame(maxWidth: 500)

        }
        .padding(compact ? 16 : 32)
        .frame(minHeight: geometry.size.height)
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func instrument(compact: Bool, condensed: Bool) -> some View {
    VStack(spacing: 0) {
      if !condensed {
        HStack(spacing: 24) {
          MicrophoneGrille().frame(height: 42).accessibilityHidden(true)
          Circle().fill(RecorderFinish.orange).frame(width: 7, height: 7)
            .accessibilityLabel("Recording in progress")
        }
        .padding(.horizontal, 28).padding(.top, 24)
      }

      HStack(alignment: .top, spacing: compact ? 10 : 16) {
        RecordingMeter(
          title: "Microphone", level: levels.microphone, compact: compact)
        RecordingMeter(title: "System Audio", level: levels.system, compact: compact)
          .help("Audio from the selected browser and its tabs")
      }
      .padding(.horizontal, compact ? 16 : 24)
      .padding(.vertical, 20)

      separator

      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(
              MarkdownExporter.timestamp(context.date.timeIntervalSince(startedAt ?? context.date))
            )
            .font(.system(size: compact ? 27 : 34, weight: .light, design: .monospaced))
            .tracking(-1.5)
            .contentTransition(.identity)
          }
          .accessibilityLabel("Recording duration")

        }
        Spacer(minLength: 0)
        VStack(spacing: 10) {
          Button(action: onStop) {
            TransportKey(compact: compact)
              .contentShape(Circle())
          }
          .buttonStyle(TransportButtonStyle(compact: compact))
          .disabled(!canStop)
          .accessibilityLabel("Stop & Transcribe")
          .help("Finish recording and transcribe this meeting")
        }
      }
      .padding(condensed ? 16 : (compact ? 20 : 24))
    }
    .foregroundStyle(.primary)
    .background {
      RoundedRectangle(cornerRadius: 20)
        .fill(
          LinearGradient(
            colors: colorScheme == .dark
              ? [RecorderFinish.ivory, RecorderFinish.lowerIvory]
              : [
                Color(red: 0.24, green: 0.25, blue: 0.24),
                Color(red: 0.15, green: 0.16, blue: 0.15),
              ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 20)
            .strokeBorder(.white.opacity(colorScheme == .dark ? 0.5 : 0.12), lineWidth: 0.5)
        }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
  }

  private var separator: some View {
    Divider().padding(.horizontal, 24)
  }
}

private enum RecorderFinish {
  static let ivory = Color(red: 0.94, green: 0.935, blue: 0.905)
  static let lowerIvory = Color(red: 0.85, green: 0.85, blue: 0.815)
  static let ink = Color(red: 0.17, green: 0.18, blue: 0.17)
  static let secondaryInk = Color(red: 0.36, green: 0.37, blue: 0.34)
  static let orange = Color(red: 0.87, green: 0.24, blue: 0.08)
  static let alertInk = Color(red: 0.65, green: 0.18, blue: 0.06)
}

private struct RecordingMeter: View {
  let title: String
  let level: RecordingLevel
  let compact: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let now = Date.now
    let receiving = level.isReceiving(at: now)
    let clipping = receiving && level.peak >= 0.99
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Text(title).font(.system(size: compact ? 10 : 12, weight: .medium))
      }
      VUDial(amount: level.amount(at: now), compact: compact)
        .frame(height: compact ? 88 : 106)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level.amount(at: now))
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Circle().fill(
          clipping
            ? RecorderFinish.orange
            : Color.primary.opacity(receiving && level.decibels > -50 ? 0.8 : 0.25)
        )
        .frame(width: 4, height: 4)
        .accessibilityHidden(true)
        Text(level.status(at: now))
          .font(.system(size: compact ? 9 : 10))
          .foregroundStyle(clipping ? Color.orange : Color.secondary)
      }
      Text(receiving ? "\(Int(level.decibels)) dBFS" : "— dBFS")
        .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.top, -5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(
      "\(level.status(at: now)), \(receiving ? String(-Int(level.decibels)) + " decibels below full scale" : "no recent audio")"
    )
  }
}

private struct VUDial: View {
  let amount: Double
  let compact: Bool

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let pivot = CGPoint(x: size.width / 2, y: size.height * 0.89)
      let radius = min((size.width / 2 - 11) / 0.82 - 9, size.height * 0.66)
      ZStack {
        RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.18))
        RoundedRectangle(cornerRadius: 4)
          .fill(
            LinearGradient(
              colors: [
                Color(red: 0.83, green: 0.835, blue: 0.77),
                Color(red: 0.96, green: 0.955, blue: 0.88),
              ], startPoint: .top, endPoint: .bottom)
          )
          .padding(4)
          .shadow(color: .black.opacity(0.8), radius: 2, y: -1)
        Canvas { context, _ in
          func point(_ fraction: Double, _ distance: Double) -> CGPoint {
            let angle = (-55 + fraction * 110) * .pi / 180
            return CGPoint(x: pivot.x + sin(angle) * distance, y: pivot.y - cos(angle) * distance)
          }
          for tick in 0...30 {
            let fraction = Double(tick) / 30
            var path = Path()
            path.move(to: point(fraction, radius))
            path.addLine(to: point(fraction, radius - (tick.isMultiple(of: 5) ? 8 : 3.5)))
            context.stroke(
              path,
              with: .color(tick >= 27 ? RecorderFinish.orange : RecorderFinish.ink.opacity(0.85)),
              lineWidth: tick.isMultiple(of: 5) ? 1 : 0.6)
            if tick.isMultiple(of: compact ? 10 : 5) {
              context.draw(
                Text("\(-60 + tick * 2)").font(.system(size: compact ? 6 : 7, weight: .medium))
                  .foregroundColor(RecorderFinish.ink), at: point(fraction, radius + 9))
            }
          }
          var redZone = Path()
          for step in 90...100 {
            let position = point(Double(step) / 100, radius - 11)
            if step == 90 { redZone.move(to: position) } else { redZone.addLine(to: position) }
          }
          context.stroke(redZone, with: .color(RecorderFinish.orange), lineWidth: 1.5)
          context.draw(
            Text("LEVEL").font(.system(size: compact ? 6 : 7, weight: .medium)).tracking(1)
              .foregroundColor(RecorderFinish.secondaryInk),
            at: CGPoint(x: pivot.x, y: pivot.y - radius * 0.28))
          context.draw(
            Text("dBFS").font(.system(size: 5.5)).foregroundColor(RecorderFinish.secondaryInk),
            at: CGPoint(x: size.width - 20, y: size.height - 12))
        }
        Rectangle().fill(RecorderFinish.ink)
          .frame(width: 1, height: radius + 2)
          .offset(y: -(radius + 2) / 2)
          .rotationEffect(.degrees(-55 + amount * 110))
          .position(pivot)
          .shadow(color: .black.opacity(0.25), radius: 0.7, x: 1.5, y: 1)
        Circle().fill(RecorderFinish.ink).frame(width: 7, height: 7).position(pivot)
        // A restrained reflection and upper shadow locate the needle behind the cover.
        RoundedRectangle(cornerRadius: 4)
          .fill(
            LinearGradient(
              stops: [
                .init(color: .black.opacity(0.16), location: 0),
                .init(color: .clear, location: 0.16),
                .init(color: .white.opacity(0.08), location: 0.6),
                .init(color: .clear, location: 1),
              ], startPoint: .top, endPoint: .bottom)
          )
          .padding(4)
      }
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .overlay {
        RoundedRectangle(cornerRadius: 7).strokeBorder(.black.opacity(0.4), lineWidth: 0.5)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.65), lineWidth: 0.5).offset(
          y: 0.5)
      }
    }
    .accessibilityHidden(true)
  }
}

private struct MicrophoneGrille: View {
  var body: some View {
    Canvas { context, size in
      let pitch: CGFloat = 7
      let columns = max(1, Int((size.width - 6) / pitch))
      let rows = max(1, Int((size.height - 6) / pitch))
      let startX = (size.width - CGFloat(columns - 1) * pitch) / 2
      let startY = (size.height - CGFloat(rows - 1) * pitch) / 2
      for row in 0..<rows {
        for column in 0..<columns {
          let hole = CGRect(
            x: startX + CGFloat(column) * pitch - 1.6, y: startY + CGFloat(row) * pitch - 1.6,
            width: 3.2, height: 3.2)
          // A lower bevel catches light; the upper lip shadows the cavity.
          context.fill(
            Path(ellipseIn: hole.offsetBy(dx: 0, dy: 0.65).insetBy(dx: -0.55, dy: -0.55)),
            with: .color(.white.opacity(0.55)))
          context.fill(
            Path(ellipseIn: hole.insetBy(dx: -0.35, dy: -0.35)),
            with: .linearGradient(
              Gradient(colors: [.black.opacity(0.55), .black.opacity(0.16)]),
              startPoint: CGPoint(x: hole.midX, y: hole.minY - 0.35),
              endPoint: CGPoint(x: hole.midX, y: hole.maxY + 0.35)))
          context.fill(
            Path(ellipseIn: hole),
            with: .linearGradient(
              Gradient(colors: [Color(white: 0.035), Color(white: 0.18)]),
              startPoint: CGPoint(x: hole.midX, y: hole.minY),
              endPoint: CGPoint(x: hole.midX, y: hole.maxY)))
          context.fill(
            Path(ellipseIn: hole.insetBy(dx: 0.6, dy: 0.6).offsetBy(dx: 0, dy: -0.35)),
            with: .color(.black.opacity(0.55)))
        }
      }
    }
  }
}

private struct TransportKey: View {
  let compact: Bool
  var pressed = false
  var hovering = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      // The bezel stays anchored while the face compresses into its well.
      Circle().fill(Color(white: 0.22))
      Circle().fill(
        LinearGradient(
          colors: [Color(white: 0.55), Color(white: 0.92)], startPoint: .top, endPoint: .bottom)
      ).padding(1)
      Circle().fill(RecorderFinish.ink).padding(3)
      ZStack {
        Circle().fill(
          LinearGradient(
            colors: [Color(red: 0.965, green: 0.96, blue: 0.93), RecorderFinish.lowerIvory],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        Circle().strokeBorder(.white.opacity(0.65), lineWidth: 0.7).padding(1)
        RoundedRectangle(cornerRadius: 2).fill(RecorderFinish.orange)
          .frame(width: compact ? 16 : 19, height: compact ? 16 : 19)
      }
      .overlay {
        Circle()
          .strokeBorder(
            LinearGradient(
              colors: [.black.opacity(pressed ? 0.28 : (hovering ? 0.14 : 0)), .clear],
              startPoint: .top, endPoint: .bottom), lineWidth: pressed ? 2 : 1)
      }
      .padding(5)
      .shadow(
        color: .black.opacity(pressed ? 0.1 : 0.28), radius: pressed ? 0.3 : 1, y: pressed ? 0 : 1
      )
      .brightness(pressed ? -0.07 : (hovering ? -0.025 : 0))
      .scaleEffect(reduceMotion ? 1 : (pressed ? 0.96 : (hovering ? 0.985 : 1)))
      .offset(y: reduceMotion ? 0 : (pressed ? 0.5 : 0))
      .clipShape(Circle().inset(by: 3))
    }
    .frame(width: compact ? 58 : 70, height: compact ? 58 : 70)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressed)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
  }
}

private struct TransportButtonStyle: ButtonStyle {
  let compact: Bool
  func makeBody(configuration: Configuration) -> some View {
    TransportButtonBody(compact: compact, pressed: configuration.isPressed)
  }
}

private struct TransportButtonBody: View {
  let compact: Bool
  let pressed: Bool
  @State private var hovering = false
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    TransportKey(compact: compact, pressed: pressed && isEnabled, hovering: hovering && isEnabled)
      .contentShape(Circle())
      .opacity(isEnabled ? 1 : 0.5)
      .onHover { hovering = $0 }
  }
}
