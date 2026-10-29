import AVFoundation
import CoreAudio
import Testing

@testable import Minutes

@Test func appAudioScopeIncludesOnlySelectedAppAndEmbeddedHelpers() {
  let scope = AppAudioScope(
    processID: 42, bundleID: "net.imput.helium", bundlePath: "/Applications/Helium.app")
  #expect(scope.includes(pid: 42, bundle: nil, executablePath: nil))
  #expect(scope.includes(pid: 80, bundle: "net.imput.helium", executablePath: nil))
  #expect(
    scope.includes(
      pid: 81, bundle: "net.imput.helium.helper",
      executablePath:
        "/Applications/Helium.app/Contents/Frameworks/Helium Helper.app/Contents/MacOS/Helium Helper"
    ))
  #expect(
    !scope.includes(
      pid: 82, bundle: "com.apple.Music",
      executablePath: "/System/Applications/Music.app/Contents/MacOS/Music"))
  #expect(
    !scope.includes(
      pid: 83, bundle: "net.imput.helium.other",
      executablePath: "/Applications/Helium.app.other/Contents/MacOS/Other"))
  #expect(!scope.includes(pid: 84, bundle: nil, executablePath: nil))
}

@Test func faceTimeScopeIncludesConferenceDaemon() {
  let scope = AppAudioScope(
    processID: 42, bundleID: "com.apple.FaceTime",
    bundlePath: "/System/Applications/FaceTime.app")
  #expect(
    scope.includes(
      pid: 90, bundle: "com.apple.avconferenced", executablePath: "/usr/libexec/avconferenced"))
  #expect(
    !scope.includes(
      pid: 91, bundle: "com.apple.TelephonyUtilities",
      executablePath:
        "/System/Library/PrivateFrameworks/TelephonyUtilities.framework/callservicesd"))
  let discord = AppAudioScope(
    processID: 43, bundleID: "com.hnc.Discord", bundlePath: "/Applications/Discord.app")
  #expect(discord.companionBundleIDs.isEmpty)
  #expect(
    !discord.includes(
      pid: 90, bundle: "com.apple.avconferenced", executablePath: "/usr/libexec/avconferenced"))
}

@Test @MainActor func appAudioCallbackRunsOnCaptureQueue() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let sink = AudioSink(directory: directory)
  let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
  let callback = AppAudioTap.makeIOCallback(format: format, sink: sink)
  let queue = DispatchQueue(label: "minutes.test.capture")
  try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    queue.async {
      do {
        #expect(!Thread.isMainThread)
        let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        pcm.frameLength = 480
        for channel in 0..<2 {
          for frame in 0..<480 { pcm.floatChannelData![channel][frame] = 0.125 }
        }
        var timestamp = AudioTimeStamp()
        timestamp.mHostTime = AVAudioTime.hostTime(forSeconds: 100)
        timestamp.mFlags = .hostTimeValid
        withUnsafePointer(to: &timestamp) { time in
          callback(time, pcm.audioBufferList, time, pcm.mutableAudioBufferList, time)
        }
        let tracks = try sink.finish()
        let file = try AVAudioFile(forReading: #require(tracks.remote))
        #expect(file.length == 480)
        let restored = try #require(
          AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 480))
        try file.read(into: restored)
        #expect(restored.floatChannelData![1][479] == 0.125)
        continuation.resume()
      } catch { continuation.resume(throwing: error) }
    }
  }
}

@Test func outputRoutingUsesConfiguredStereoPair() {
  let proFX = AppAudioRoute.selection(channelCounts: [4], preferred: [3, 4])
  #expect(proFX?.stream == 0)
  #expect(proFX?.channels == [2, 3])
  let separate = AppAudioRoute.selection(channelCounts: [2, 2], preferred: [3, 4])
  #expect(separate?.stream == 1)
  #expect(separate?.channels == [0, 1])
  #expect(AppAudioRoute.selection(channelCounts: [2], preferred: [3, 4]) == nil)
  #expect(AppAudioRoute.selection(channelCounts: [2, 2], preferred: [2, 3]) == nil)
  #expect(AppAudioRoute.selection(channelCounts: [4], preferred: [0, 1]) == nil)
}

@Test func systemAudioExtractsOutputsThreeAndFour() throws {
  for interleaved in [false, true] {
    var description = AudioStreamBasicDescription(
      mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        | (interleaved ? 0 : kAudioFormatFlagIsNonInterleaved),
      mBytesPerPacket: interleaved ? 16 : 4, mFramesPerPacket: 1,
      mBytesPerFrame: interleaved ? 16 : 4,
      mChannelsPerFrame: 4, mBitsPerChannel: 32, mReserved: 0)
    let layout = try #require(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Quadraphonic))
    let format = try #require(AVAudioFormat(streamDescription: &description, channelLayout: layout))
    let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
    pcm.frameLength = 480
    for channel in 0..<4 {
      for frame in 0..<480 {
        let value: Float = channel == 2 ? 0.25 : channel == 3 ? -0.5 : 0
        if interleaved { pcm.floatChannelData![0][frame * 4 + channel] = value }
        else { pcm.floatChannelData![channel][frame] = value }
      }
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let sink = AudioSink(directory: directory)
    let callback = AppAudioTap.makeIOCallback(format: format, sink: sink, channels: [2, 3])
    var timestamp = AudioTimeStamp()
    timestamp.mHostTime = AVAudioTime.hostTime(forSeconds: 100)
    timestamp.mFlags = .hostTimeValid
    withUnsafePointer(to: &timestamp) { time in
      callback(time, pcm.audioBufferList, time, pcm.mutableAudioBufferList, time)
    }
    #expect(sink.takeLevels().system.peak == 0.5)
    let tracks = try sink.finish()
    let file = try AVAudioFile(forReading: #require(tracks.remote))
    let restored = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 480))
    try file.read(into: restored)
    #expect(restored.format.channelCount == 2)
    #expect(restored.floatChannelData![0][479] == 0.25)
    #expect(restored.floatChannelData![1][479] == -0.5)
  }
}
