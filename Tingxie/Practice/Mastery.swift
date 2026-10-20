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

    /// Drill sessions stop at the next item boundary after this long.
    static let sessionCap: TimeInterval = 5 * 60

    /// Drill: items still being learned. Fresh misses first, then items one clean recall
    /// away from mastery; each group shuffled so order can't be memorised.
    static func drillPool(_ sheet: Sheet) -> [Item] {
        let learning = sheet.orderedItems.filter { $0.status == .learning }
        return learning.filter { $0.cleanStreak == 0 }.shuffled() + learning.filter { $0.cleanStreak > 0 }.shuffled()
    }

    /// Mock unlocks when every item is mastered, or when a parent overrides.
    static func mockReady(_ sheet: Sheet) -> Bool {
        !sheet.items.isEmpty && (sheet.mockUnlocked || sheet.items.allSatisfy { $0.status == .mastered })
    }

    /// Learn covers new items; once none are new it re-teaches anything not yet mastered.
    static func learnPool(_ sheet: Sheet) -> [Item] {
        let items = sheet.orderedItems
        let fresh = items.filter { $0.status == .new }
        return fresh.isEmpty ? items.filter { $0.status != .mastered } : fresh
    }
}
