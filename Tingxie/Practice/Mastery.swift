import Foundation

enum Mastery {
    /// Clean recalls in separate sessions needed to master an item.
    static let streakToMaster = 2

    /// Apply one recall attempt. A miss (wrong, or any hint) resets the streak.
    /// Only the first attempt per session can count toward mastery, so a retry
    /// later in the same session is practice, not proof.
    static func apply(clean: Bool, to item: Item, session: UUID) {
        if !clean {
            item.status = .learning
            item.cleanStreak = 0
            item.misses += 1
            item.lastSeenSession = session
            return
        }
        guard item.lastSeenSession != session else { return }
        item.cleanStreak += 1
        item.status = item.cleanStreak >= streakToMaster ? .mastered : .learning
        item.lastSeenSession = session
    }

    /// Learn covers new items; once none are new it re-teaches anything not yet mastered.
    static func learnPool(_ sheet: Sheet) -> [Item] {
        let items = sheet.orderedItems
        let fresh = items.filter { $0.status == .new }
        return fresh.isEmpty ? items.filter { $0.status != .mastered } : fresh
    }
}
