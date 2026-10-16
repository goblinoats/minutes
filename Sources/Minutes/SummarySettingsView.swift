import SwiftUI

struct SummarySettingsView: View {
  @Bindable var connection: ChatGPTConnection

  var body: some View {
    Form {
      Section("ChatGPT") {
        HStack {
          if connection.isConnected {
            Text(connection.accountEmail ?? "Connected").textSelection(.enabled)
            Spacer()
            Button("Sign Out") { Task { await connection.signOut() } }
              .disabled(connection.busy)
          } else {
            Button("Sign In") { connection.signIn() }.disabled(connection.busy)
            if connection.isSigningIn {
              ProgressView().controlSize(.small)
              Text("Waiting for ChatGPT sign-in…").foregroundStyle(.secondary)
              Spacer()
              Button("Cancel") { connection.cancelSignIn() }
            }
          }
        }
        if let error = connection.error {
          Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled)
        }
      }
      Section {
        HStack {
          if !connection.models.isEmpty {
            Picker("Model", selection: $connection.selectedModel) {
              ForEach(connection.models) { item in Text(item.displayName).tag(item.id) }
            }.disabled(connection.busy)
          } else {
            LabeledContent(
              "Model", value: connection.isConnected ? "No models loaded" : "Sign in to choose")
          }
          Button("Refresh Models", systemImage: "arrow.clockwise") {
            Task { await connection.refreshModels() }
          }
          .labelStyle(.iconOnly).help("Refresh models")
          .disabled(!connection.isConnected || connection.busy)
        }
        Toggle("Automatically summarize transcripts", isOn: $connection.automaticSummaries)
          .disabled(!connection.isConnected || connection.busy)
        Link(
          "Manage ChatGPT usage and app access",
          destination: URL(string: "https://chatgpt.com/settings/usage")!)
      } header: {
        Text("Meeting Summaries")
      } footer: {
        Text("Summaries send transcript text and speaker names to OpenAI. Audio stays on your Mac.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped).scrollContentBackground(.hidden)
    .task { await connection.refreshModels() }
  }
}
