import MinutesCore
import SwiftUI

struct VocabularySettingsView: View {
  @Bindable var model: AppModel
  @ViewState private var draft = ""
  /// Kept apart from the text: a field that disappears while focused commits
  /// its text afterwards, which must not reopen replacement entry.
  @ViewState private var replacing = false
  @ViewState private var replacement = ""
  @ViewState private var showingHelp = false
  @FocusState private var focus: Field?

  private enum Field { case draft, replacement }

  private enum Entry: Hashable {
    case word(String)
    case replacement(TextReplacement)

    var sortKey: String {
      switch self {
      case .word(let word): word
      case .replacement(let rule): rule.heard
      }
    }
  }

  var body: some View {
    Form {
      Section {
        entryField
      } header: {
        HStack(spacing: 4) {
          Text("Vocabulary")
          Button("About Vocabulary", systemImage: "info.circle") { showingHelp.toggle() }
            .labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.secondary)
            .popover(isPresented: $showingHelp, arrowEdge: .bottom) { help }
        }
      } footer: {
        if entries.isEmpty {
          Text("Add names, jargon, and anything else that is often misheard.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      if !entries.isEmpty {
        Section {
          ForEach(entries, id: \.self) { entry in
            EntryRow(entry: entry) { remove(entry) }
          }
        }
      }
      Section {
        Toggle("Improve recognition", isOn: $model.vocabularyBoosting)
      } footer: {
        Text(
          "Listens for your words while transcribing, catching some that would otherwise be misheard. Downloads a 100 MB English model and adds a few minutes per hour of audio."
        )
        .font(.caption).foregroundStyle(.secondary)
      }
    }.formStyle(.grouped).scrollContentBackground(.hidden)
  }

  private var entryField: some View {
    HStack(spacing: 8) {
      TextField("New Word or Replacement", text: $draft, prompt: Text("New word or replacement"))
        .labelsHidden().textFieldStyle(.plain).focused($focus, equals: .draft)
        .onSubmit { !replacing ? addWord() : (focus = .replacement) }
      if replacing {
        Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityHidden(true)
        TextField(
          "Replace With",
          text: $replacement,
          prompt: Text("Replace with")
        )
        .labelsHidden().textFieldStyle(.plain).focused($focus, equals: .replacement)
        .onSubmit(addReplacement)
        Hint("Add", keys: ["return"], action: addReplacement)
          .disabled(isBlank(draft) || isBlank(replacement))
        Hint("Cancel", keys: ["escape"], action: endReplacement)
          .keyboardShortcut(.cancelAction)
      } else {
        Hint("Add Word", keys: ["return"], action: addWord).disabled(isBlank(draft))
        Hint("Replace With…", keys: ["command", "return"], action: beginReplacement)
          .disabled(isBlank(draft))
          .keyboardShortcut(.return, modifiers: .command)
      }
    }
  }

  private var help: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(
        "**Words** are spelled your way. Capitals, spaces, and hyphens are ignored when matching, so “open ai” becomes “OpenAI”. Avoid common words, because every match changes."
      )
      Text(
        "**Replacements** swap something that is consistently misheard, such as “cube control” → “kubectl”."
      )
      Text("Changes apply to new and regenerated transcripts.").foregroundStyle(.secondary)
    }
    .font(.callout).fixedSize(horizontal: false, vertical: true)
    .frame(width: 300).padding(16)
  }

  private var entries: [Entry] {
    (model.corrections.dictionary.map(Entry.word)
      + model.corrections.replacements.map(Entry.replacement))
      .sorted { $0.sortKey.localizedStandardCompare($1.sortKey) == .orderedAscending }
  }

  private func isBlank(_ text: String) -> Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func addWord() {
    guard !isBlank(draft) else { return }
    model.addDictionaryTerm(draft)
    draft = ""
  }

  private func beginReplacement() {
    guard !isBlank(draft) else {
      focus = .draft
      return
    }
    replacement = ""
    replacing = true
    focus = .replacement
  }

  private func addReplacement() {
    guard replacing, !isBlank(draft), !isBlank(replacement) else { return }
    model.addReplacement(heard: draft, replacement: replacement)
    draft = ""
    endReplacement()
  }

  private func endReplacement() {
    replacing = false
    replacement = ""
    focus = .draft
  }

  private func remove(_ entry: Entry) {
    switch entry {
    case .word(let word): model.corrections.dictionary.removeAll { $0 == word }
    case .replacement(let rule): model.corrections.replacements.removeAll { $0 == rule }
    }
  }

  /// A quiet button that shows its keyboard shortcut, like a menu item.
  private struct Hint: View {
    let title: String
    let keys: [String]
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, keys: [String], action: @escaping () -> Void) {
      self.title = title
      self.keys = keys
      self.action = action
    }

    var body: some View {
      Button(action: action) {
        HStack(spacing: 4) {
          Text(title).padding(.trailing, 2)
          ForEach(keys, id: \.self) { key in
            Image(systemName: key).font(.caption2.weight(.semibold))
              .frame(width: 20, height: 20)
              .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
          }
        }
        .foregroundStyle(isEnabled ? .secondary : .tertiary)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(title)
    }
  }

  private struct EntryRow: View {
    let entry: Entry
    let remove: () -> Void
    @ViewState private var hovering = false

    var body: some View {
      HStack(spacing: 12) {
        switch entry {
        case .word(let word):
          Text(word)
        case .replacement(let rule):
          Text(rule.heard).foregroundStyle(.secondary)
            .frame(minWidth: 160, alignment: .leading)
          Image(systemName: "arrow.right").font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
          Text(rule.replacement)
        }
        Spacer(minLength: 0)
        Button("Remove", systemImage: "minus.circle.fill", action: remove)
          .labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.secondary)
          .help("Remove")
          .opacity(hovering ? 1 : 0)
          .accessibilityHidden(true)
      }
      .contentShape(Rectangle())
      .onHover { hovering = $0 }
      .contextMenu { Button("Remove", action: remove) }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(label)
      .accessibilityAction(named: "Remove", remove)
    }

    private var label: String {
      switch entry {
      case .word(let word): word
      case .replacement(let rule): "\(rule.heard), replaced with \(rule.replacement)"
      }
    }
  }
}
