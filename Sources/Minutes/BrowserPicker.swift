import AppKit
import SwiftUI

struct BrowserSource: Identifiable {
  let processID: pid_t
  let applicationName: String
  var id: pid_t { processID }

  static func isBrowser(_ bundleID: String) -> Bool {
    [
      "com.apple.Safari", "com.apple.SafariTechnologyPreview",
      "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev",
      "com.google.Chrome.canary",
      "org.chromium.Chromium", "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition",
      "org.mozilla.nightly",
      "net.imput.helium", "company.thebrowser.Browser",
      "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
      "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev",
      "com.microsoft.edgemac.Canary",
      "com.operasoftware.Opera", "com.operasoftware.OperaGX", "com.vivaldi.Vivaldi",
      "com.kagi.kagimacOS", "app.zen-browser.zen", "com.duckduckgo.macos.browser",
    ].contains(bundleID)
  }

  @MainActor static func running() -> [BrowserSource] {
    NSWorkspace.shared.runningApplications.compactMap { app in
      guard app.activationPolicy == .regular, !app.isTerminated,
        let bundleID = app.bundleIdentifier, isBrowser(bundleID), let name = app.localizedName
      else { return nil }
      return BrowserSource(processID: app.processIdentifier, applicationName: name)
    }.sorted {
      $0.applicationName.localizedCaseInsensitiveCompare($1.applicationName) == .orderedAscending
    }
  }
}

/// The recorder's system-audio source: the selected browser as a quiet menu.
struct BrowserSourceMenu: View {
  @Bindable var model: AppModel

  var body: some View {
    Group {
      if let selected = model.applications.first(where: { $0.processID == model.sourceID }) {
        Menu {
          Picker("Browser", selection: $model.sourceID) {
            ForEach(model.applications) { app in
              Text(app.applicationName).tag(app.processID)
            }
          }.pickerStyle(.inline)
        } label: {
          // A plain style lets the label inherit the meter caption's type.
          HStack(spacing: 3) {
            Text(selected.applicationName)
            Image(systemName: "chevron.up.chevron.down").imageScale(.small)
          }
          .contentShape(Rectangle())
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .help("Browser to record")
      } else {
        Text("No browser open")
      }
    }
    .refreshingBrowserSources(model)
  }
}

extension View {
  fileprivate func refreshingBrowserSources(_ model: AppModel) -> some View {
    self
      .onAppear { model.refreshSources() }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in
        model.refreshSources()
      }
      .onReceive(
        NSWorkspace.shared.notificationCenter.publisher(
          for: NSWorkspace.didLaunchApplicationNotification)
      ) { _ in
        model.refreshSources()
      }
      .onReceive(
        NSWorkspace.shared.notificationCenter.publisher(
          for: NSWorkspace.didTerminateApplicationNotification)
      ) { _ in
        model.refreshSources()
      }
  }
}
