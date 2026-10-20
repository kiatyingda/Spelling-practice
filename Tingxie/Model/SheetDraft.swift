import Foundation
import SwiftData

/// Editable copy of a sheet, so Cancel discards and Save applies in one go.
/// Also the hand-off from the photo-capture confirm screen (step 5).
struct SheetDraft {
    struct Line: Identifiable, Equatable {
        let id: UUID
        var text: String
        var type: ItemType
        /// A manual word/sentence toggle wins over re-guessing on edit.
        var typeTouched: Bool

        init(id: UUID = UUID(), text: String, type: ItemType, typeTouched: Bool = false) {
            self.id = id
            self.text = text
            self.type = type
            self.typeTouched = typeTouched
        }
    }

    var title: String
    var lang: Lang
    var lines: [Line]

    init(lang: Lang, title: String = "", lines: [Line] = []) {
        self.lang = lang
        self.title = title
        self.lines = lines
    }

    init(sheet: Sheet) {
        lang = sheet.lang
        title = sheet.title
        lines = sheet.orderedItems.map { Line(id: $0.id, text: $0.text, type: $0.type, typeTouched: true) }
    }

    /// One item per non-empty line of pasted text.
    mutating func append(pasted: String) {
        for raw in pasted.split(whereSeparator: \.isNewline) {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { lines.append(Line(text: t, type: ItemTyping.guess(t, lang: lang))) }
        }
    }

    static func defaultTitle(for date: Date) -> String {
        "Week of " + date.formatted(.dateTime.day().month(.abbreviated))
    }
}

enum SheetStore {
    /// Applies `draft` to `sheet` (or a new sheet). Changing an item's text makes it a different
    /// word, so its progress resets; any change to the word list clears `testReady`.
    /// Returns nil when the draft has no items.
    @discardableResult
    static func save(_ draft: SheetDraft, into sheet: Sheet?, context: ModelContext, now: Date = .now) -> Sheet? {
        let lines = draft.lines
            .map { line -> SheetDraft.Line in
                var l = line
                l.text = l.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return l
            }
            .filter { !$0.text.isEmpty }
        guard !lines.isEmpty else { return nil }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: Sheet
        if let sheet {
            target = sheet
        } else {
            target = Sheet(title: "", lang: draft.lang, createdAt: now)
            context.insert(target)
        }
        target.title = title.isEmpty ? SheetDraft.defaultTitle(for: target.createdAt) : title

        var changed = false
        let existing = Dictionary(uniqueKeysWithValues: target.items.map { ($0.id, $0) })
        let keep = Set(lines.map(\.id))

        for item in target.items where !keep.contains(item.id) {
            context.delete(item)
            changed = true
        }
        target.items.removeAll { !keep.contains($0.id) }

        for (index, line) in lines.enumerated() {
            if let item = existing[line.id] {
                if item.text != line.text {
                    item.text = line.text
                    item.resetProgress()
                    changed = true
                }
                item.type = line.type
                item.order = index
            } else {
                let item = Item(text: line.text, type: line.type, order: index)
                context.insert(item)
                target.items.append(item)
                changed = true
            }
        }
        if changed { target.testReady = false }
        try? context.save()
        return target
    }
}
