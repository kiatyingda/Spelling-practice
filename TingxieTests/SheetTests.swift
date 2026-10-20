import SwiftData
import XCTest
@testable import Tingxie

@MainActor
final class SheetTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer(
            for: Sheet.self, Item.self, SessionLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testGuessType() {
        XCTAssertEqual(ItemTyping.guess("美丽", lang: .zh), .word)
        XCTAssertEqual(ItemTyping.guess("我们一起去公园。", lang: .zh), .sentence)
        XCTAssertEqual(ItemTyping.guess("一二三四五六七", lang: .zh), .sentence)
        XCTAssertEqual(ItemTyping.guess("beautiful", lang: .en), .word)
        XCTAssertEqual(ItemTyping.guess("I like it.", lang: .en), .sentence)
        XCTAssertEqual(ItemTyping.guess("the big red bus", lang: .en), .sentence)
    }

    func testPasteSplitsLines() {
        var d = SheetDraft(lang: .zh)
        d.append(pasted: "美丽\n\n  我们一起去公园。 \n")
        XCTAssertEqual(d.lines.map(\.text), ["美丽", "我们一起去公园。"])
        XCTAssertEqual(d.lines.map(\.type), [.word, .sentence])
    }

    func testCreateKeepsOrderAndDefaultsTitle() throws {
        var d = SheetDraft(lang: .en)
        d.append(pasted: "cat\ndog\n  \nbird")
        let sheet = try XCTUnwrap(SheetStore.save(d, into: nil, context: context))
        XCTAssertEqual(sheet.orderedItems.map(\.text), ["cat", "dog", "bird"])
        XCTAssertTrue(sheet.title.hasPrefix("Week of "))
        XCTAssertNil(SheetStore.save(SheetDraft(lang: .en), into: nil, context: context))
    }

    func testEditingTextResetsOnlyThatItemAndClearsTestReady() throws {
        var d = SheetDraft(lang: .en, title: "W1")
        d.append(pasted: "cat\ndog")
        let sheet = try XCTUnwrap(SheetStore.save(d, into: nil, context: context))
        for item in sheet.items {
            item.status = .mastered
            item.cleanStreak = 2
            item.misses = 1
        }
        sheet.testReady = true

        var edit = SheetDraft(sheet: sheet)
        edit.lines[1].text = "dot"
        edit.lines.swapAt(0, 1)
        SheetStore.save(edit, into: sheet, context: context)

        let items = sheet.orderedItems
        XCTAssertEqual(items.map(\.text), ["dot", "cat"])
        XCTAssertEqual(items[0].status, .new)
        XCTAssertEqual(items[0].cleanStreak, 0)
        XCTAssertEqual(items[1].status, .mastered)
        XCTAssertFalse(sheet.testReady)
    }

    func testReorderOnlyKeepsTestReady() throws {
        var d = SheetDraft(lang: .en, title: "W1")
        d.append(pasted: "cat\ndog")
        let sheet = try XCTUnwrap(SheetStore.save(d, into: nil, context: context))
        sheet.testReady = true
        var edit = SheetDraft(sheet: sheet)
        edit.lines.swapAt(0, 1)
        SheetStore.save(edit, into: sheet, context: context)
        XCTAssertEqual(sheet.orderedItems.map(\.text), ["dog", "cat"])
        XCTAssertTrue(sheet.testReady)
    }

    func testRemovingAnItemDeletesIt() throws {
        var d = SheetDraft(lang: .en, title: "W1")
        d.append(pasted: "cat\ndog")
        let sheet = try XCTUnwrap(SheetStore.save(d, into: nil, context: context))
        var edit = SheetDraft(sheet: sheet)
        edit.lines.removeFirst()
        SheetStore.save(edit, into: sheet, context: context)
        XCTAssertEqual(sheet.items.map(\.text), ["dog"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Item>()), 1)
    }

    func testVoiceRankingPrefersExactLocaleAndQuality() {
        let voices = [
            VoiceCandidate(identifier: "a", name: "Albert", language: "en-GB", quality: .default),
            VoiceCandidate(identifier: "b", name: "Daniel", language: "en-GB", quality: .default),
            VoiceCandidate(identifier: "c", name: "Serena", language: "en-GB", quality: .premium),
            VoiceCandidate(identifier: "d", name: "Samantha", language: "en-US", quality: .enhanced),
            VoiceCandidate(identifier: "e", name: "Tingting", language: "zh-CN", quality: .default),
        ]
        XCTAssertEqual(VoiceCandidate.ranked(voices, for: .en).map(\.identifier), ["c", "b", "a", "d"])
        XCTAssertEqual(VoiceCandidate.ranked(voices, for: .zh).map(\.identifier), ["e"])
    }
}
