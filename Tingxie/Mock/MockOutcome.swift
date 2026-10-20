import Foundation
import SwiftData

/// One marked mock answer. `correct` starts from the vision marking; a parent can flip it.
struct MockMark: Identifiable, Equatable {
    let n: Int
    let itemId: UUID
    let expected: String
    var written: String
    var correct: Bool
    var note: String

    var id: Int { n }
}

enum MockOutcome {
    /// Misses go back to Drill (learning, streak reset); a clean run marks the sheet test-ready.
    static func apply(_ marks: [MockMark], to sheet: Sheet, startedAt: Date, context: ModelContext, now: Date = .now) {
        let byId = Dictionary(uniqueKeysWithValues: sheet.items.map { ($0.id, $0) })
        for mark in marks where !mark.correct {
            guard let item = byId[mark.itemId] else { continue }
            item.status = .learning
            item.cleanStreak = 0
            item.misses += 1
        }
        let clean = !marks.isEmpty && marks.allSatisfy(\.correct)
        sheet.testReady = clean
        if !clean { sheet.mockUnlocked = false }
        context.insert(SessionLog(sheetId: sheet.id, mode: .mock, startedAt: startedAt, endedAt: now,
                                  masteredCount: sheet.count(.mastered)))
        try? context.save()
    }
}
