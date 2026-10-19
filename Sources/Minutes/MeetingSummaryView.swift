import MinutesCore
import SwiftUI

struct MeetingSummaryView: View {
  let summary: MeetingSummary?
  let isGenerating: Bool
  let canGenerate: Bool
  let generate: () -> Void
  @ViewState private var isExpanded = true
  @ViewState private var copyFeedback: String?
  @ViewState private var copyAttempt: UUID?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        if isGenerating && summary == nil {
          summaryLabel
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Summarizing")
        } else {
          Button {
            if summary == nil {
              isExpanded = true
              generate()
            } else {
              withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                isExpanded.toggle()
              }
            }
          } label: {
            summaryLabel
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(isGenerating ? "Summarizing" : "Summarize")
          .disabled(summary == nil && !canGenerate)
          .accessibilityValue(
            summary == nil ? "Not generated" : isExpanded ? "Expanded" : "Collapsed"
          )
          .accessibilityHint(
            summary == nil ? "Generate summary" : isExpanded ? "Collapse summary" : "Expand summary"
          )
          .help(
            summary == nil ? "Generate summary" : isExpanded ? "Collapse summary" : "Expand summary"
          )
          .contextMenu {
            if summary != nil {
              Button("Regenerate Summary", action: generate).disabled(!canGenerate)
            }
          }

        }
        Spacer()
        if let summary {
          if copyFeedback == "Copy failed" {
            Text("Copy failed").font(.caption).foregroundStyle(.secondary)
          }
          Button {
            NSPasteboard.general.clearContents()
            let copied = NSPasteboard.general.setString(summary.markdown, forType: .string)
            copyFeedback = copied ? "Copied" : "Copy failed"
            copyAttempt = UUID()
          } label: {
            Label(
              "Copy Summary", systemImage: copyFeedback == "Copied" ? "checkmark" : "doc.on.doc")
          }
          .labelStyle(.iconOnly).buttonStyle(.borderless)
          .frame(minWidth: 28, minHeight: 28)
          .accessibilityValue(copyFeedback ?? "")
          .help("Copy summary as Markdown")
          .task(id: copyAttempt) {
            guard copyAttempt != nil else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            copyFeedback = nil
          }
        }
      }
      if isExpanded, let summary {
        VStack(alignment: .leading, spacing: 16) {
          SummaryMarkdownView(markdown: summary.markdown)
          Text("Generated with ChatGPT · \(summary.model)")
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
      }
    }
    .onChange(of: summary?.generatedAt) {
      isExpanded = true
      copyFeedback = nil
    }
  }

  private var summaryLabel: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      SummaryActivityIcon(isAnimating: isGenerating && !reduceMotion)
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
      Text(isGenerating ? "Summarizing…" : "Summarize")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Color(nsColor: .systemGray))
    }
    .frame(minHeight: 28)
  }

}

private struct SummaryActivityIcon: View {
  let isAnimating: Bool

  var body: some View {
    Group {
      if #available(macOS 26, *) {
        if isAnimating {
          DrawingSummarySymbol()
        } else {
          Image(systemName: "text.line.2.summary")
        }
      } else {
        Image(systemName: "text.alignleft")
      }
    }
    .font(.system(size: 13, weight: .regular))
    .foregroundStyle(Color(nsColor: .systemGray))
  }
}

@available(macOS 26, *)
private struct DrawingSummarySymbol: View {
  // Draw On's active state is hidden; drawing occurs when it becomes inactive.
  @ViewState private var isHidden = true

  var body: some View {
    Image(systemName: "text.line.2.summary")
      .symbolEffect(.drawOn.byLayer, options: .nonRepeating, isActive: isHidden)
      .task {
        do {
          // Let the initial hidden state mount before drawing the symbol on.
          try await Task.sleep(for: .milliseconds(50))
          while !Task.isCancelled {
            isHidden = false
            try await Task.sleep(for: .seconds(1.8))
            isHidden = true
            try await Task.sleep(for: .milliseconds(800))
          }
        } catch {
          // Removing the loading view cancels this cycle.
        }
      }
  }
}
