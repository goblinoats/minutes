import AVFoundation
import Testing

@testable import Minutes

@Test func recordingLevelsMeasureBothChannelsAndKeepPeaksBetweenPolls() throws {
  let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
  let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
  buffer.frameLength = 480
  for frame in 0..<480 {
    buffer.floatChannelData![0][frame] = 0
    buffer.floatChannelData![1][frame] = 0.5
  }
  let now = Date()
  var meter = RecordingLevelAccumulator()
  meter.consume(buffer, now: now)
  let level = meter.takeReading()
  #expect(abs(level.decibels - (-9.0309)) < 0.001)
  #expect(level.peak == 0.5)
  #expect(level.status(at: now) == "Signal detected")
  buffer.floatChannelData![1][0] = 1
  meter.consume(buffer, now: now)
  buffer.floatChannelData![1][0] = 0.5
  meter.consume(buffer, now: now)
  #expect(meter.takeReading().status(at: now) == "Clipping")
  meter.consume(buffer, now: now)
  #expect(meter.takeReading().peak == 0.5)
  #expect(level.amount(at: now.addingTimeInterval(1)) == 0)
  #expect(level.status(at: now.addingTimeInterval(1)) == "No recent audio")
}

@Test func recordingLevelsHandleInterleavedIntegerAudioAndSilence() throws {
  let format = try #require(
    AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true))
  let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 20))
  buffer.frameLength = 20
  let data = buffer.int16ChannelData![0]
  for index in 0..<40 { data[index] = index.isMultiple(of: 2) ? 16384 : -16384 }
  var meter = RecordingLevelAccumulator()
  let now = Date()
  meter.consume(buffer, now: now)
  #expect(abs(meter.takeReading().decibels - (-6.0206)) < 0.001)
  for index in 0..<40 { data[index] = 0 }
  meter.consume(buffer, now: now)
  let silent = meter.takeReading()
  #expect(silent.decibels == -60)
  #expect(silent.status(at: now) == "Quiet")
  #expect(RecordingLevel().status(at: now) == "Waiting for audio")
}

@Test func captureMetersKeepMicrophoneAndSystemSeparate() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
  let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160))
  buffer.frameLength = 160
  let sink = AudioSink(directory: directory)
  for frame in 0..<160 { buffer.floatChannelData![0][frame] = 0.5 }
  sink.consume(buffer, at: 100, of: .microphone)
  for frame in 0..<160 { buffer.floatChannelData![0][frame] = 0.125 }
  sink.consume(buffer, at: 100, of: .audio)
  let levels = sink.takeLevels()
  #expect(abs(levels.microphone.decibels - (-6.0206)) < 0.001)
  #expect(abs(levels.system.decibels - (-18.0618)) < 0.001)
  let tracks = try sink.finish()
  #expect(try AVAudioFile(forReading: #require(tracks.microphone)).length == 160)
  #expect(try AVAudioFile(forReading: #require(tracks.remote)).length == 160)
}
