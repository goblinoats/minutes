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
          HStack(spacing: 5) {
            SummarySymbol()
              .fill(Color(nsColor: .systemGray))
              .frame(width: 16, height: 16)
              .accessibilityHidden(true)
            Text("Summarize")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(Color(nsColor: .systemGray))
          }
          .frame(minHeight: 28)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Summarize")
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

        if isGenerating {
          ProgressView().controlSize(.small)
          Text("Summarizing…").font(.caption).foregroundStyle(.secondary)
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
}

/// Mail's summary glyph: two text lines over a curved arrow with a filled head.
private struct SummarySymbol: Shape {
  func path(in rect: CGRect) -> Path {
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x / 16 * rect.width, y: rect.minY + y / 16 * rect.height)
    }
    var lines = Path()
    for (y, end) in [(CGFloat(3), CGFloat(12)), (7, 9)] {
      lines.move(to: point(5, y))
      lines.addLine(to: point(end, y))
    }
    lines.move(to: point(1, 3))
    lines.addLine(to: point(1, 8))
    lines.addQuadCurve(to: point(5, 12), control: point(1, 12))
    lines.addLine(to: point(12, 12))
    var result = lines.strokedPath(
      StrokeStyle(lineWidth: rect.width / 16, lineCap: .round, lineJoin: .round))
    result.move(to: point(11, 9))
    result.addLine(to: point(15, 12))
    result.addLine(to: point(11, 15))
    result.closeSubpath()
    return result
  }
}
