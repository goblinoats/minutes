import Testing

@testable import Minutes

@Test func audioSourcesExcludeNonBrowserWebHandlers() {
  for id in ["net.imput.helium", "com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox"] {
    #expect(AudioSource.kind(of: id) == .browser)
  }
  for id in [
    "com.openai.codex", "com.cmuxterm.app", "app.bearing.mac", "com.google.Chrome.helper", "",
  ] {
    #expect(AudioSource.kind(of: id) == nil)
  }
}

@Test func audioSourcesIncludeCallApps() {
  for id in [
    "com.apple.FaceTime", "net.whatsapp.WhatsApp", "com.hnc.Discord", "us.zoom.xos",
    "com.microsoft.teams2", "com.tinyspeck.slackmacgap",
  ] {
    #expect(AudioSource.kind(of: id) == .callApp)
  }
  for id in ["com.hnc.Discord.helper", "com.apple.avconferenced", "com.apple.Music"] {
    #expect(AudioSource.kind(of: id) == nil)
  }
}
