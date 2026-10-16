import SwiftUI

/// Foundation parses Markdown; SwiftUI supplies the block layout that Text alone omits.
struct SummaryMarkdownBlock {
  var text: AttributedString
  var intent: PresentationIntent?

  var headingLevel: Int? {
    for component in intent?.components ?? [] {
      if case .header(let level) = component.kind { return level }
    }
    return nil
  }
  var listDepth: Int {
    (intent?.components ?? []).filter {
      $0.kind == .orderedList || $0.kind == .unorderedList
    }.count
  }
  var marker: String? {
    let components = intent?.components ?? []
    guard
      let item = components.first(where: {
        if case .listItem = $0.kind { return true }
        return false
      }), case .listItem(let ordinal) = item.kind
    else { return nil }
    let list = components.first { $0.kind == .orderedList || $0.kind == .unorderedList }
    return list?.kind == .orderedList ? "\(ordinal)." : "•"
  }
  var isCode: Bool {
    (intent?.components ?? []).contains {
      if case .codeBlock = $0.kind { return true }
      return false
    }
  }
  var isQuote: Bool { intent?.components.contains { $0.kind == .blockQuote } == true }

  static func parse(_ markdown: String) -> [Self] {
    guard let parsed = try? AttributedString(markdown: markdown) else {
      return [.init(text: AttributedString(markdown), intent: nil)]
    }
    var blocks: [Self] = []
    for run in parsed.runs {
      let text = AttributedString(parsed[run.range])
      if let last = blocks.last, last.intent == run.presentationIntent {
        blocks[blocks.count - 1].text.append(text)
      } else {
        blocks.append(.init(text: text, intent: run.presentationIntent))
      }
    }
    return blocks
  }
}

struct SummaryMarkdownView: View {
  private let blocks: [SummaryMarkdownBlock]

  init(markdown: String) { blocks = SummaryMarkdownBlock.parse(markdown) }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(blocks.indices, id: \.self) { index in
        let block = blocks[index]
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          if let marker = block.marker {
            Text(marker).foregroundStyle(.secondary)
              .frame(minWidth: 14, alignment: .trailing)
          }
          Text(block.text)
            .font(font(for: block))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(max(0, block.listDepth - 1)) * 20)
        .padding(.top, block.headingLevel != nil && index > 0 ? 10 : 0)
        .padding(block.isCode || block.isQuote ? 10 : 0)
        .background {
          if block.isCode || block.isQuote {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
          }
        }
        .accessibilityAddTraits(block.headingLevel != nil ? .isHeader : [])
      }
    }
  }

  private func font(for block: SummaryMarkdownBlock) -> Font {
    if let level = block.headingLevel {
      return level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline
    }
    return block.isCode ? .body.monospaced() : .body
  }
}
