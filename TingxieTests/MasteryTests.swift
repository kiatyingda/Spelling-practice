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
