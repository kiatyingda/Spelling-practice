import SwiftData
import XCTest
@testable import Tingxie

@MainActor
final class MockTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer(
            for: Sheet.self, Item.self, SessionLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func masteredSheet() throws -> Sheet {
        var d = SheetDraft(lang: .zh, title: "W")
        d.append(pasted: "美丽\n公园\n朋友")
        let s = try XCTUnwrap(SheetStore.save(d, into: nil, context: context))
        for item in s.items {
            item.status = .mastered
            item.cleanStreak = 2
        }
        return s
    }

    private func marks(_ sheet: Sheet, wrong: Set<String> = []) -> [MockMark] {
        sheet.orderedItems.enumerated().map { i, item in
            MockMark(n: i + 1, itemId: item.id, expected: item.text, written: item.text, correct: !wrong.contains(item.text), note: "")
        }
    }

    func testCleanRunSetsTestReadyAndLogs() throws {
        let s = try masteredSheet()
        MockOutcome.apply(marks(s), to: s, startedAt: .now, context: context)
        XCTAssertTrue(s.testReady)
        XCTAssertEqual(s.count(.mastered), 3)
        let logs = try context.fetch(FetchDescriptor<SessionLog>())
        XCTAssertEqual(logs.map(\.mode), [.mock])
    }

    func testMissesGoBackToDrill() throws {
        let s = try masteredSheet()
        s.mockUnlocked = true
        MockOutcome.apply(marks(s, wrong: ["公园"]), to: s, startedAt: .now, context: context)
        XCTAssertFalse(s.testReady)
        XCTAssertFalse(s.mockUnlocked)
        let missed = try XCTUnwrap(s.items.first { $0.text == "公园" })
        XCTAssertEqual(missed.status, .learning)
        XCTAssertEqual(missed.cleanStreak, 0)
        XCTAssertEqual(missed.misses, 1)
        XCTAssertEqual(Mastery.drillPool(s).map(\.text), ["公园"])
        XCTAssertFalse(Mastery.mockReady(s))
    }
}
