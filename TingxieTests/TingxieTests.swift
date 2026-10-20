import XCTest
@testable import Tingxie

final class ShellTests: XCTestCase {
    func testParentGateHoldsForOneAndAHalfSeconds() {
        XCTAssertEqual(LongPressGate.duration, 1.5)
    }
}
