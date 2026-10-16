import Foundation
import Testing

@testable import Minutes

@Test func summaryMarkdownRendersBlocksAndPreservesInlineFormatting() throws {
  let blocks = SummaryMarkdownBlock.parse(
    """
    ### Overview
    A **clear** decision with a [reference](https://example.com).

    ### Actions
    - **Alice:** Ship Friday.
    - Bob: Review.

    1. First step
    2. Second step
    """)
  #expect(blocks.count == 7)
  #expect(blocks[0].headingLevel == 3)
  #expect(String(blocks[0].text.characters) == "Overview")
  #expect(
    blocks[1].text.runs.contains {
      $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
    })
  #expect(blocks[1].text.runs.contains { $0.link == URL(string: "https://example.com") })
  #expect(blocks[3].marker == "•")
  #expect(String(blocks[3].text.characters) == "Alice: Ship Friday.")
  #expect(blocks[5].marker == "1.")
  #expect(blocks[6].marker == "2.")
}

@Test func summaryMarkdownHandlesNestedListsQuotesAndCode() {
  let blocks = SummaryMarkdownBlock.parse(
    """
    - Parent
      - Child

    > A quoted point.

    ```swift
    let value = 1
    ```
    """)
  #expect(blocks.contains { $0.listDepth == 2 })
  #expect(blocks.contains { $0.isQuote })
  #expect(blocks.contains { $0.isCode })
}
