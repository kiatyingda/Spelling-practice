import SwiftData
import XCTest
@testable import Tingxie

final class MasteryTests: XCTestCase {
    func testTwoCleanRecallsInSeparateSessionsMaster() {
        let item = Item(text: "美丽", type: .word, order: 0)
        let s1 = UUID(), s2 = UUID()
        Mastery.apply(clean: true, to: item, session: s1)
        XCTAssertEqual(item.status, .learning)
        XCTAssertEqual(item.cleanStreak, 1)
        Mastery.apply(clean: true, to: item, session: s2)
        XCTAssertEqual(item.status, .mastered)
    }

    func testRetryInSameSessionDoesNotCount() {
        let item = Item(text: "cat", type: .word, order: 0)
        let s = UUID()
        Mastery.apply(clean: true, to: item, session: s)
        Mastery.apply(clean: true, to: item, session: s)
        XCTAssertEqual(item.cleanStreak, 1)
        XCTAssertEqual(item.status, .learning)
    }

    func testMissResetsStreakAndCounts() {
        let item = Item(text: "cat", type: .word, order: 0)
        Mastery.apply(clean: true, to: item, session: UUID())
        let s = UUID()
        Mastery.apply(clean: false, to: item, session: s)
        XCTAssertEqual(item.cleanStreak, 0)
        XCTAssertEqual(item.misses, 1)
        XCTAssertEqual(item.status, .learning)
        // A clean retry later in the same session is practice only.
        Mastery.apply(clean: true, to: item, session: s)
        XCTAssertEqual(item.cleanStreak, 0)
    }
}

@MainActor
final class PoolTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(
            for: Sheet.self, Item.self, SessionLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func sheet(_ statuses: [(ItemStatus, Int)]) -> Sheet {
        let s = Sheet(title: "W", lang: .en)
        container.mainContext.insert(s)
        for (i, (status, streak)) in statuses.enumerated() {
            let item = Item(text: "w\(i)", type: .word, order: i)
            container.mainContext.insert(item)
            item.status = status
            item.cleanStreak = streak
            s.items.append(item)
        }
        return s
    }

    func testLearnPoolPrefersNewThenUnmastered() {
        let s = sheet([(.new, 0), (.learning, 1), (.mastered, 2)])
        XCTAssertEqual(Mastery.learnPool(s).map(\.text), ["w0"])
        s.orderedItems[0].status = .learning
        XCTAssertEqual(Mastery.learnPool(s).map(\.text), ["w0", "w1"])
    }

    func testDrillPoolIsLearningOnlyWithMissesFirst() {
        let s = sheet([(.learning, 1), (.new, 0), (.learning, 0), (.mastered, 2), (.learning, 0), (.learning, 1)])
        let pool = Mastery.drillPool(s).map(\.text)
        XCTAssertEqual(Set(pool), ["w0", "w2", "w4", "w5"])
        XCTAssertEqual(Set(pool.prefix(2)), ["w2", "w4"])
    }

    func testMockReadyNeedsAllMasteredOrOverride() {
        let s = sheet([(.mastered, 2), (.learning, 1)])
        XCTAssertFalse(Mastery.mockReady(s))
        s.mockUnlocked = true
        XCTAssertTrue(Mastery.mockReady(s))
        s.mockUnlocked = false
        s.orderedItems[1].status = .mastered
        XCTAssertTrue(Mastery.mockReady(s))
        XCTAssertFalse(Mastery.mockReady(sheet([])))
    }

    func testDrillCapIsAboutFiveMinutes() {
        XCTAssertEqual(Mastery.sessionCap, 300)
    }
}
