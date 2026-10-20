import AVFoundation

struct RecordingLevel: Sendable {
  var decibels: Double = -60
  var peak: Double = 0
  var receivedAt: Date?

  func isReceiving(at now: Date) -> Bool {
    receivedAt.map { now.timeIntervalSince($0) < 0.5 } ?? false
  }

  func amount(at now: Date) -> Double {
    isReceiving(at: now) ? min(1, max(0, (decibels + 60) / 60)) : 0
  }

  func status(at now: Date) -> String {
    guard isReceiving(at: now) else {
      return receivedAt == nil ? "Waiting for audio" : "No recent audio"
    }
    if peak >= 0.99 { return "Clipping" }
    return decibels > -50 ? "Signal detected" : "Quiet"
  }
}

struct RecordingLevels: Sendable {
  var microphone = RecordingLevel()
  var system = RecordingLevel()
}

// Owned by the capture queue. Accumulate between UI polls so short peaks aren't lost.
struct RecordingLevelAccumulator {
  private var sumSquares: Double = 0
  private var count = 0
  private var peak: Double = 0
  private var receivedAt: Date?
  private var latest = RecordingLevel()

  mutating func consume(_ buffer: AVAudioPCMBuffer, now: Date = .now) {
    guard buffer.frameLength > 0 else { return }
    let previousCount = count
    for audio in UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList) {
      guard let data = audio.mData else { continue }
      let samples = Int(buffer.frameLength) * Int(audio.mNumberChannels)
      func collect<T>(_ type: T.Type, scale: Double, value: (T) -> Double) {
        let length = min(samples, Int(audio.mDataByteSize) / MemoryLayout<T>.stride)
        let values = data.assumingMemoryBound(to: T.self)
        for index in 0..<length {
          let sample = value(values[index]) / scale
          guard sample.isFinite else { continue }
          sumSquares += sample * sample
          peak = max(peak, abs(sample))
          count += 1
        }
      }
      switch buffer.format.commonFormat {
      case .pcmFormatFloat32: collect(Float.self, scale: 1, value: Double.init)
      case .pcmFormatFloat64: collect(Double.self, scale: 1, value: { $0 })
      case .pcmFormatInt16: collect(Int16.self, scale: 32768, value: Double.init)
      case .pcmFormatInt32: collect(Int32.self, scale: 2_147_483_648, value: Double.init)
      default: continue
      }
    }
    if count > previousCount { receivedAt = now }
  }

  mutating func takeReading() -> RecordingLevel {
    if count > 0 {
      latest = RecordingLevel(
        decibels: max(-60, min(0, 10 * log10(max(sumSquares / Double(count), 1e-12)))),
        peak: peak, receivedAt: receivedAt)
    }
    sumSquares = 0
    count = 0
    peak = 0
    return latest
  }
}
