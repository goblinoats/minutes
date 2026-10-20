import AVFoundation
import Testing

@testable import Minutes

@Test @MainActor func recordingCuesDecodeAsShortQuietAudioWithSilentEdges() throws {
  for cue in RecordingSounds.Cue.allCases {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try cue.wave().write(to: url)
    let file = try AVAudioFile(forReading: url)
    #expect(file.processingFormat.channelCount == 1)
    #expect(abs(Double(file.length) / file.processingFormat.sampleRate - cue.duration) < 0.001)
    let buffer = try #require(
      AVAudioPCMBuffer(
        pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
    try file.read(into: buffer)
    let samples = try #require(buffer.floatChannelData?[0])
    let values = (0..<Int(buffer.frameLength)).map { abs(samples[$0]) }
    #expect(values.max()! > 0.01)
    #expect(values.max()! < 0.4)
    #expect(values.first! < 0.001)
    #expect(values.last! < 0.001)
  }
}
