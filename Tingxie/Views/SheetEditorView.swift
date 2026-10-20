import SwiftData
import SwiftUI

/// Create or edit a sheet. The photo-capture confirm screen (step 5) reuses it with a pre-filled draft.
struct SheetEditorView: View {
    let sheet: Sheet?
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var draft: SheetDraft
    @State private var paste = ""
    @State private var showEmptyAlert = false
    @State private var confirmDelete = false

    init(draft: SheetDraft, sheet: Sheet?, onClose: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.sheet = sheet
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: sheet == nil ? "New sheet" : "Edit sheet") {
                    Button("← Cancel", action: onClose).buttonStyle(.surface)
                } trailing: {
                    Button("Save", action: save).buttonStyle(.prominentSurface)
                }

                HStack(spacing: 12) {
                    TextField("Title, e.g. 第5课 听写", text: $draft.title)
                        .font(.title3)
                        .fieldStyle()
                    Picker("Language", selection: $draft.lang) {
                        ForEach(Lang.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .disabled(sheet != nil)
                }

                VStack(spacing: 8) {
                    ForEach($draft.lines) { $line in
                        row($line)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $paste)
                            .font(.title3)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if paste.isEmpty {
                            Text(draft.lang == .zh ? "一行一个词语或句子\n例如：\n美丽\n我们一起去公园。" : "One word or sentence per line")
                                .font(.title3)
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
                    Button("Add items") {
                        draft.append(pasted: paste)
                        paste = ""
                    }
                    .buttonStyle(.surface)
                    .disabled(paste.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let sheet {
                    Panel {
                        Toggle(isOn: Binding(
                            get: { sheet.mockUnlocked },
                            set: { sheet.mockUnlocked = $0; try? context.save() }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Allow Mock 听写 now").font(.headline)
                                Text("Normally it unlocks once every item is mastered.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .frame(minHeight: Theme.touch)
                    }
                    Button("Delete sheet", role: .destructive) { confirmDelete = true }
                        .buttonStyle(.surface)
                        .foregroundStyle(Theme.miss)
                }
            }
        }
        .screen()
        .alert("Add at least one item.", isPresented: $showEmptyAlert) {}
        .confirmationDialog("Delete \"\(draft.title)\"? Progress will be lost.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private func row(_ line: Binding<SheetDraft.Line>) -> some View {
        let id = line.wrappedValue.id
        let index = draft.lines.firstIndex { $0.id == id } ?? 0
        return HStack(spacing: 8) {
            Text("\(index + 1)")
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
                .frame(width: 32, alignment: .trailing)
            TextField("", text: line.text)
                .font(.title3)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .fieldStyle()
                .onChange(of: line.wrappedValue.text) { _, text in
                    if !line.wrappedValue.typeTouched { line.wrappedValue.type = ItemTyping.guess(text, lang: draft.lang) }
                }
            iconButton("play.fill", "Play") {
                Task { await Speech.shared.speak(line.wrappedValue.text, lang: draft.lang) }
            }
            Button(line.wrappedValue.type.label(draft.lang)) {
                line.wrappedValue.type = line.wrappedValue.type == .word ? .sentence : .word
                line.wrappedValue.typeTouched = true
            }
            .buttonStyle(.surface)
            .foregroundStyle(Theme.muted)
            .frame(minWidth: 112)
            iconButton("arrow.up", "Move up") { move(index, by: -1) }
                .disabled(index == 0)
            iconButton("arrow.down", "Move down") { move(index, by: 1) }
                .disabled(index == draft.lines.count - 1)
            iconButton("xmark", "Delete") { draft.lines.removeAll { $0.id == id } }
                .foregroundStyle(Theme.miss)
        }
    }

    private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 24)
        }
        .buttonStyle(SurfaceButtonStyle(compact: true))
        .accessibilityLabel(label)
    }

    private func move(_ i: Int, by d: Int) {
        let j = i + d
        guard draft.lines.indices.contains(i), draft.lines.indices.contains(j) else { return }
        draft.lines.swapAt(i, j)
    }

    private func save() {
        guard let saved = SheetStore.save(draft, into: sheet, context: context) else {
            showEmptyAlert = true
            return
        }
        if saved.lang == .zh {
            // Cache stroke data now so writing practice works offline later.
            let text = saved.items.map(\.text).joined()
            Task.detached { await HanziData.shared.prefetch(text) }
        }
        onClose()
    }

    private func delete() {
        guard let sheet else { return }
        let sheetId = sheet.id
        try? context.delete(model: SessionLog.self, where: #Predicate { $0.sheetId == sheetId })
        context.delete(sheet)
        try? context.save()
        onClose()
    }
}
