import AppKit

/// Short, quiet mechanical cues, synthesized locally with no audio assets.
@MainActor
final class RecordingSounds {
  enum Cue: CaseIterable {
    case start, stop, finished

    var duration: Double { self == .finished ? 0.28 : 0.07 }

    func wave() -> Data {
      let rate = 22_050
      let count = Int(duration * Double(rate))
      var samples = Data()
      for index in 0..<count {
        let t = Double(index) / Double(rate)
        let attack = min(1, t / 0.002)
        let release = min(1, (duration - t) / 0.008)
        let frequency: Double = self == .start ? 920 : (self == .stop ? 620 : 1320)
        let decay = exp(-t * (self == .finished ? 19 : 75))
        var value = sin(2 * .pi * frequency * t) * decay
        // A second, softer resonance gives completion a gentle rising tail.
        if self == .finished && t > 0.07 {
          value +=
            0.55 * sin(2 * .pi * 1760 * (t - 0.07))
            * min(1, (t - 0.07) / 0.003) * exp(-(t - 0.07) * 23)
        }
        var sample = Int16(value * attack * release * 8000).littleEndian
        withUnsafeBytes(of: &sample) { samples.append(contentsOf: $0) }
      }
      var data = Data("RIFF".utf8)
      func append<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
      }
      append(UInt32(36 + samples.count))
      data.append(Data("WAVEfmt ".utf8))
      append(UInt32(16))
      append(UInt16(1))
      append(UInt16(1))
      append(UInt32(rate))
      append(UInt32(rate * 2))
      append(UInt16(2))
      append(UInt16(16))
      data.append(Data("data".utf8))
      append(UInt32(samples.count))
      data.append(samples)
      return data
    }
  }

  private var sound: NSSound?

  func play(_ cue: Cue) {
    sound?.stop()
    sound = NSSound(data: cue.wave())
    sound?.volume = 0.35
    sound?.play()
  }

  func beforeCapture() async throws {
    play(.start)
    // Finish playback and leave a short acoustic tail before opening the mic.
    try await Task.sleep(for: .milliseconds(180))
    sound?.stop()
  }
}
