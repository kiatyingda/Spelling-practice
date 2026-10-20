import Foundation
import SwiftData

enum Lang: String, Codable, CaseIterable, Identifiable {
    case zh, en
    var id: String { rawValue }
    var label: String { self == .zh ? "中文" : "English" }
    var bcp47: String { self == .zh ? "zh-CN" : "en-GB" }
}

enum ItemType: String, Codable {
    case word, sentence

    func label(_ lang: Lang) -> String {
        switch (self, lang) {
        case (.word, .zh): "词语"
        case (.sentence, .zh): "句子"
        case (.word, .en): "Word"
        case (.sentence, .en): "Sentence"
        }
    }
}

enum ItemStatus: String, Codable {
    case new, learning, mastered
}

enum SessionMode: String, Codable {
    case learn, drill, mock
}

// Enums are stored as raw strings: SwiftData predicates and migrations handle plain values best.

@Model
final class Sheet {
    @Attribute(.unique) var id: UUID
    var title: String
    var langRaw: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Item.sheet) var items: [Item]
    var testReady: Bool
    /// Parent override: allow Mock before every item is mastered.
    var mockUnlocked: Bool

    init(title: String, lang: Lang, createdAt: Date = .now) {
        id = UUID()
        self.title = title
        langRaw = lang.rawValue
        self.createdAt = createdAt
        items = []
        testReady = false
        mockUnlocked = false
    }

    var lang: Lang { Lang(rawValue: langRaw) ?? .zh }

    /// SwiftData relationships are unordered; `order` keeps the teacher's sequence.
    var orderedItems: [Item] { items.sorted { $0.order < $1.order } }

    func count(_ status: ItemStatus) -> Int { items.filter { $0.status == status }.count }
}

@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var text: String
    var typeRaw: String
    var statusRaw: String
    var cleanStreak: Int
    var lastSeenSession: UUID?
    var misses: Int
    var order: Int
    var sheet: Sheet?

    init(text: String, type: ItemType, order: Int) {
        id = UUID()
        self.text = text
        typeRaw = type.rawValue
        statusRaw = ItemStatus.new.rawValue
        cleanStreak = 0
        lastSeenSession = nil
        misses = 0
        self.order = order
    }

    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .word }
        set { typeRaw = newValue.rawValue }
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    func resetProgress() {
        status = .new
        cleanStreak = 0
        misses = 0
        lastSeenSession = nil
    }
}

@Model
final class SessionLog {
    @Attribute(.unique) var id: UUID
    var sheetId: UUID
    var modeRaw: String
    var startedAt: Date
    var endedAt: Date
    var masteredCount: Int

    init(id: UUID = UUID(), sheetId: UUID, mode: SessionMode, startedAt: Date, endedAt: Date, masteredCount: Int) {
        self.id = id
        self.sheetId = sheetId
        modeRaw = mode.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.masteredCount = masteredCount
    }

    var mode: SessionMode { SessionMode(rawValue: modeRaw) ?? .learn }
}

enum ItemTyping {
    /// Same heuristic as the web version: punctuation or length means sentence.
    static func guess(_ text: String, lang: Lang) -> ItemType {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch lang {
        case .zh:
            let punct = CharacterSet(charactersIn: "。，！？；：、,.!?")
            return t.unicodeScalars.contains(where: punct.contains) || t.count > 6 ? .sentence : .word
        case .en:
            let words = t.split(whereSeparator: \.isWhitespace).count
            return t.last.map { ".!?".contains($0) } == true || words >= 4 ? .sentence : .word
        }
    }
}
