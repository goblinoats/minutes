import MinutesCore
import SwiftUI

/// A small recording instrument: lacquered shell, recessed meters, physical transport key.
struct RecordingView: View {
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
            .frame(maxWidth: 500)
          if geometry.size.height >= 500 {
            Text("Transcription starts when you stop.")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        .padding(compact ? 16 : 32)
        .frame(minHeight: geometry.size.height)
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func instrument(compact: Bool, condensed: Bool) -> some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .firstTextBaseline) {
          Text("minutes")
            .font(.system(size: 23, weight: .semibold))
            .tracking(-1)
          Spacer()
          if condensed {
            HStack(spacing: 6) {
              Circle().fill(RecorderFinish.orange).frame(width: 5, height: 5)
              Text("RECORDING").font(.system(size: 8, weight: .medium)).tracking(1.2)
            }
          } else {
            Text("MEETING RECORDER")
              .font(.system(size: 8, weight: .medium)).tracking(1.6)
              .foregroundStyle(RecorderFinish.secondaryInk)
          }
        }
        if !condensed {
          HStack(spacing: compact ? 20 : 30) {
            MicrophoneGrille()
              .frame(height: compact ? 76 : 84)
              .accessibilityHidden(true)
            VStack(spacing: 9) {
              Text("REC").font(.system(size: 8, weight: .semibold)).tracking(1.5)
              RecordingLamp().frame(width: 14, height: 34)
              Text("LIVE").font(.system(size: 7, weight: .medium)).tracking(1)
                .foregroundStyle(RecorderFinish.secondaryInk)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recording in progress")
            .padding(.trailing, 4)
          }
        }
      }
      .padding(condensed ? 16 : (compact ? 20 : 24))

      separator

      HStack(alignment: .top, spacing: compact ? 10 : 16) {
        RecordingMeter(
          number: "01", title: "Microphone", level: levels.microphone, compact: compact)
        RecordingMeter(number: "02", title: "System Audio", level: levels.system, compact: compact)
          .help("Audio from the selected browser and its tabs")
      }
      .padding(.horizontal, compact ? 16 : 24)
      .padding(.vertical, 20)

      separator

      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("ELAPSED").font(.system(size: 8, weight: .medium)).tracking(1.5)
            .foregroundStyle(RecorderFinish.secondaryInk)
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(
              MarkdownExporter.timestamp(context.date.timeIntervalSince(startedAt ?? context.date))
            )
            .font(.system(size: compact ? 27 : 34, weight: .light, design: .monospaced))
            .tracking(-1.5)
            .contentTransition(.identity)
          }
          .accessibilityLabel("Recording duration")
          HStack(spacing: 5) {
            Image(systemName: "lock").font(.system(size: 8))
            Text("On-device audio").font(.system(size: 9))
          }
          .foregroundStyle(RecorderFinish.secondaryInk)
        }
        Spacer(minLength: 0)
        VStack(spacing: 10) {
          Button(action: onStop) {
            TransportKey(compact: compact)
              .contentShape(Circle())
          }
          .buttonStyle(TransportButtonStyle())
          .disabled(!canStop)
          .accessibilityLabel("Stop & Transcribe")
          .help("Finish recording and transcribe this meeting")
          Text("Stop & Transcribe")
            .font(.system(size: compact ? 9 : 10, weight: .medium))
            .accessibilityHidden(true)
        }
      }
      .padding(condensed ? 16 : (compact ? 20 : 24))
    }
    .foregroundStyle(RecorderFinish.ink)
    .background {
      RoundedRectangle(cornerRadius: 22)
        .fill(
          LinearGradient(
            colors: [RecorderFinish.ivory, RecorderFinish.lowerIvory], startPoint: .topLeading,
            endPoint: .bottomTrailing)
        )
        .overlay { SurfaceGrain().clipShape(RoundedRectangle(cornerRadius: 22)) }
        .overlay {
          RoundedRectangle(cornerRadius: 21).strokeBorder(
            LinearGradient(
              colors: [.white.opacity(0.95), .white.opacity(0.16), .black.opacity(0.14)],
              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5
          )
          .padding(1)
        }
        .overlay {
          RoundedRectangle(cornerRadius: 22).strokeBorder(.black.opacity(0.16), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
        .shadow(color: .black.opacity(0.13), radius: 16, y: 12)
    }
    .overlay(alignment: .topLeading) { AssemblyScrew().padding(9) }
    .overlay(alignment: .topTrailing) { AssemblyScrew().padding(9) }
    .overlay(alignment: .bottomLeading) { AssemblyScrew().padding(9) }
    .overlay(alignment: .bottomTrailing) { AssemblyScrew().padding(9) }
  }

  private var separator: some View {
    Rectangle().fill(.black.opacity(0.15)).frame(height: 0.5)
      .overlay(alignment: .bottom) {
        Rectangle().fill(.white.opacity(0.7)).frame(height: 0.5).offset(y: 0.5)
      }
      .padding(.horizontal, 1)
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
  let number: String
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
        Text(number).font(.system(size: 8, weight: .medium, design: .monospaced))
          .foregroundStyle(RecorderFinish.secondaryInk)
        Text(title).font(.system(size: compact ? 10 : 12, weight: .medium))
      }
      VUDial(amount: level.amount(at: now), compact: compact)
        .frame(height: compact ? 88 : 106)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level.amount(at: now))
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Circle().fill(
          clipping
            ? RecorderFinish.orange
            : RecorderFinish.ink.opacity(receiving && level.decibels > -50 ? 0.8 : 0.25)
        )
        .frame(width: 4, height: 4)
        .accessibilityHidden(true)
        Text(level.status(at: now))
          .font(.system(size: compact ? 9 : 10))
          .foregroundStyle(clipping ? RecorderFinish.alertInk : RecorderFinish.secondaryInk)
      }
      Text(receiving ? "\(Int(level.decibels)) dBFS" : "— dBFS")
        .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
        .foregroundStyle(RecorderFinish.secondaryInk)
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
          context.fill(
            Path(ellipseIn: hole.offsetBy(dx: 0, dy: 0.6).insetBy(dx: -0.4, dy: -0.4)),
            with: .color(.white.opacity(0.85)))
          context.fill(
            Path(ellipseIn: hole.insetBy(dx: -0.3, dy: -0.3)), with: .color(.black.opacity(0.23)))
          context.fill(Path(ellipseIn: hole), with: .color(RecorderFinish.ink))
          context.fill(
            Path(ellipseIn: hole.insetBy(dx: 0.4, dy: 0.4).offsetBy(dx: 0, dy: -0.3)),
            with: .color(.black.opacity(0.6)))
        }
      }
    }
  }
}

private struct RecordingLamp: View {
  var body: some View {
    Capsule().fill(Color(white: 0.13))
      .overlay { Capsule().strokeBorder(.black.opacity(0.5), lineWidth: 1) }
      .overlay(alignment: .bottom) {
        Circle().fill(RecorderFinish.orange)
          .overlay { Circle().fill(.orange.opacity(0.4)).blur(radius: 3) }
          .overlay { Circle().fill(.white.opacity(0.45)).frame(width: 3, height: 2).offset(y: -2) }
          .frame(width: 8, height: 8).padding(.bottom, 5)
      }
      .overlay { Capsule().strokeBorder(.white.opacity(0.65), lineWidth: 0.5).offset(y: 0.5) }
  }
}

private struct TransportKey: View {
  let compact: Bool
  var body: some View {
    ZStack {
      Circle().fill(Color(white: 0.22))
      Circle().fill(
        LinearGradient(
          colors: [Color(white: 0.55), Color(white: 0.92)], startPoint: .top, endPoint: .bottom)
      ).padding(1)
      Circle().fill(RecorderFinish.ink).padding(3)
      Circle().fill(
        LinearGradient(
          colors: [Color(red: 0.965, green: 0.96, blue: 0.93), RecorderFinish.lowerIvory],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      )
      .padding(5)
      .shadow(color: .black.opacity(0.28), radius: 1, y: 1)
      Circle().strokeBorder(.white.opacity(0.65), lineWidth: 0.7).padding(6)
      RoundedRectangle(cornerRadius: 2).fill(RecorderFinish.orange)
        .frame(width: compact ? 16 : 19, height: compact ? 16 : 19)
        .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
    }
    .frame(width: compact ? 58 : 70, height: compact ? 58 : 70)
  }
}

private struct TransportButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var isEnabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
      .brightness(configuration.isPressed ? -0.04 : 0)
      .opacity(isEnabled ? 1 : 0.5)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

private struct AssemblyScrew: View {
  var body: some View {
    Circle().fill(.black.opacity(0.12))
      .overlay { Circle().fill(RecorderFinish.ivory).padding(0.8) }
      .overlay {
        Capsule().fill(.black.opacity(0.25)).frame(width: 3, height: 0.6).rotationEffect(
          .degrees(-35))
      }
      .frame(width: 5, height: 5)
      .accessibilityHidden(true)
  }
}

private struct SurfaceGrain: View {
  var body: some View {
    Canvas { context, size in
      // Fixed pattern, not animated noise; subtle enough to read as a finish, not decoration.
      for index in 0..<6000 {
        let x = CGFloat((index * 73) % 997) / 997 * size.width
        let y = CGFloat((index * 197) % 991) / 991 * size.height
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: 0.6, height: 0.6)),
          with: .color(index.isMultiple(of: 2) ? .white.opacity(0.13) : .black.opacity(0.035)))
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
