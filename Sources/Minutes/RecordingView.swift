import SwiftUI

struct RecordingView: View {
  let levels: RecordingLevels

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 24) {
          VintageMicrophone()
            .frame(width: 190, height: min(260, max(70, geometry.size.height - 390)))
            .accessibilityHidden(true)
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { meters(compact: geometry.size.width < 420) }
            VStack(spacing: 16) { meters(compact: false) }
          }
          .frame(maxWidth: 520)
          if geometry.size.height >= 480 {
            Text("Transcription starts when you stop.")
              .font(.caption).foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
        }
        .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 104)
        .frame(minHeight: geometry.size.height)
        .frame(maxWidth: .infinity)
      }
    }
  }

  @ViewBuilder private func meters(compact: Bool) -> some View {
    RecordingMeter(title: "Microphone", symbol: "mic", level: levels.microphone, compact: compact)
    RecordingMeter(
      title: "System Audio", symbol: "speaker.wave.2", level: levels.system, compact: compact
    )
    .help("Audio from the selected browser and its tabs")
  }
}

private struct RecordingMeter: View {
  let title: String
  let symbol: String
  let level: RecordingLevel
  let compact: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let now = Date.now
    let receiving = level.isReceiving(at: now)
    let clipping = receiving && level.peak >= 0.99
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: symbol)
        Text(title).fontWeight(.medium)
        Spacer(minLength: 0)
      }
      .font(.callout)
      VUDial(amount: level.amount(at: now))
        .frame(height: compact ? 90 : 114)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level.amount(at: now))
      Group {
        if compact {
          VStack(alignment: .leading, spacing: 2) {
            status(now: now, receiving: receiving, clipping: clipping)
          }
        } else {
          HStack(spacing: 8) {
            Text(level.status(at: now))
              .foregroundStyle(clipping ? Color.red : Color.secondary)
            Spacer(minLength: 0)
            Text(receiving ? "\(Int(level.decibels)) dBFS" : "—")
              .monospacedDigit().foregroundStyle(.secondary)
          }
        }
      }
      .font(.caption)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(minWidth: 120, maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(
      "\(level.status(at: now)), \(receiving ? String(-Int(level.decibels)) + " decibels below full scale" : "no recent audio")"
    )
  }

  @ViewBuilder private func status(now: Date, receiving: Bool, clipping: Bool) -> some View {
    Text(level.status(at: now))
      .foregroundStyle(clipping ? Color.red : Color.secondary)
    Text(receiving ? "\(Int(level.decibels)) dBFS" : "—")
      .monospacedDigit().foregroundStyle(.secondary)
  }
}

private struct VUDial: View {
  let amount: Double
  private let ink = Color(red: 0.24, green: 0.20, blue: 0.14)

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let pivot = CGPoint(x: size.width / 2, y: size.height * 0.94)
      let radius = min((size.width / 2 - 14) / 0.82 - 10, size.height * 0.79)
      ZStack {
        RoundedRectangle(cornerRadius: 13)
          .fill(
            LinearGradient(
              colors: [
                Color(red: 0.88, green: 0.82, blue: 0.65), Color(red: 1, green: 0.96, blue: 0.83),
              ],
              startPoint: .top, endPoint: .bottom))
        Canvas { context, _ in
          func point(_ fraction: Double, _ distance: Double) -> CGPoint {
            let angle = (-55 + fraction * 110) * .pi / 180
            return CGPoint(x: pivot.x + sin(angle) * distance, y: pivot.y - cos(angle) * distance)
          }
          for tick in 0...20 {
            let fraction = Double(tick) / 20
            var path = Path()
            path.move(to: point(fraction, radius))
            path.addLine(to: point(fraction, radius - (tick.isMultiple(of: 4) ? 10 : 5)))
            context.stroke(
              path, with: .color(tick >= 18 ? .red.opacity(0.8) : ink.opacity(0.75)), lineWidth: 1)
            if tick.isMultiple(of: 4) {
              context.draw(
                Text("\(-60 + tick * 3)").font(.system(size: 8, weight: .medium, design: .rounded))
                  .foregroundColor(ink),
                at: point(fraction, radius + 10))
            }
          }
          var arc = Path()
          for step in 0...100 {
            let position = point(Double(step) / 100, radius - 14)
            if step == 0 { arc.move(to: position) } else { arc.addLine(to: position) }
          }
          context.stroke(arc, with: .color(ink.opacity(0.25)), lineWidth: 0.7)
          context.draw(
            Text("VU").font(
              .system(size: min(16, radius * 0.24), weight: .semibold, design: .serif)
            ).foregroundColor(
              ink.opacity(0.65)), at: CGPoint(x: pivot.x, y: pivot.y - radius * 0.32))
        }
        Rectangle()
          .fill(ink)
          .frame(width: 1.5, height: radius - 3)
          .offset(y: -(radius - 3) / 2)
          .rotationEffect(.degrees(-55 + amount * 110))
          .position(pivot)
          .shadow(color: .black.opacity(0.2), radius: 1, x: 2, y: 1)
        Circle().fill(ink).frame(width: 9, height: 9).position(pivot)
      }
      .clipShape(RoundedRectangle(cornerRadius: 13))
      .overlay {
        RoundedRectangle(cornerRadius: 13)
          .strokeBorder(.black.opacity(0.22), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    .accessibilityHidden(true)
  }
}

/// A vector homage to the original Voice Memos microphone, with a quieter finish.
struct VintageMicrophone: View {
  private let chrome = LinearGradient(
    colors: [
      Color(white: 0.35), Color(white: 0.87), .white, Color(white: 0.52), Color(white: 0.76),
    ],
    startPoint: .leading, endPoint: .trailing)

  var body: some View {
    GeometryReader { geometry in
      let height = geometry.size.height
      let width = height * 0.53
      ZStack(alignment: .top) {
        Ellipse().fill(.black.opacity(0.13))
          .frame(width: width * 1.25, height: 12)
          .blur(radius: 7).offset(y: height - 9)
        RoundedRectangle(cornerRadius: 3).fill(chrome)
          .frame(width: 12, height: height * 0.21).offset(y: height * 0.74)
        Ellipse().fill(chrome)
          .frame(width: width * 0.83, height: 10).offset(y: height - 12)
        Path { path in
          path.move(to: CGPoint(x: -width * 0.1, y: height * 0.35))
          path.addLine(to: CGPoint(x: -width * 0.1, y: height * 0.49))
          path.addCurve(
            to: CGPoint(x: width * 1.1, y: height * 0.49),
            control1: CGPoint(x: -width * 0.1, y: height * 0.88),
            control2: CGPoint(x: width * 1.1, y: height * 0.88))
          path.addLine(to: CGPoint(x: width * 1.1, y: height * 0.35))
        }
        .stroke(chrome, style: StrokeStyle(lineWidth: 5, lineCap: .round))
        .frame(width: width)
        RoundedRectangle(cornerRadius: width / 2)
          .fill(
            LinearGradient(
              colors: [Color(white: 0.85), Color(white: 0.36), Color(white: 0.13)],
              startPoint: .topLeading, endPoint: .bottomTrailing)
          )
          .overlay {
            Canvas { context, size in
              let pitch: CGFloat = 4.5
              for row in 0..<Int(size.height / pitch) {
                for column in 0..<Int(size.width / pitch) {
                  let x = CGFloat(column) * pitch + (row.isMultiple(of: 2) ? 0 : pitch / 2)
                  let y = CGFloat(row) * pitch
                  let hole = CGRect(x: x, y: y, width: 2.1, height: 2.1)
                  context.fill(
                    Path(ellipseIn: hole.offsetBy(dx: 0, dy: 0.7)),
                    with: .color(.white.opacity(0.3)))
                  context.fill(Path(ellipseIn: hole), with: .color(.black.opacity(0.8)))
                }
              }
            }
            .clipShape(RoundedRectangle(cornerRadius: width / 2))
          }
          .frame(width: width, height: height * 0.72)
          .overlay(alignment: .center) {
            Rectangle().fill(chrome).frame(height: height * 0.075)
              .overlay {
                Image(systemName: "waveform").font(.system(size: height * 0.04, weight: .medium))
                  .foregroundStyle(.black.opacity(0.35))
              }
              .offset(y: height * 0.035)
          }
          .shadow(color: .black.opacity(0.18), radius: 9, y: 5)
        ForEach([-1.0, 1.0], id: \.self) { side in
          RoundedRectangle(cornerRadius: 2).fill(chrome)
            .frame(width: 7, height: 14)
            .offset(x: side * width * 0.59, y: height * 0.36)
        }
      }
      .frame(maxWidth: .infinity)
    }
  }
}
