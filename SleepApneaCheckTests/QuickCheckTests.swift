import XCTest
@testable import SleepApneaCheck

final class QuickCheckTests: XCTestCase {

    func testLowRiskWhenAllNo() {
        let result = QuickCheckCalculator.evaluate(
            answers: [.no, .no, .no, .no, .no]
        )
        XCTAssertEqual(result.totalPoints, 0)
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertFalse(result.hasObservedPause)
        XCTAssertFalse(result.summaryMessage.isEmpty)
    }

    func testIntermediateRiskWhenScoreBetween3And5WithoutObservedPause() {
        let result = QuickCheckCalculator.evaluate(
            answers: [.yes, .no, .unsure, .no, .no]
        )
        XCTAssertEqual(result.totalPoints, 3)
        XCTAssertEqual(result.riskLevel, .intermediate)
        XCTAssertFalse(result.hasObservedPause)
    }

    func testHighRiskWhenObservedPauseIsYesEvenIfOtherNo() {
        let result = QuickCheckCalculator.evaluate(
            answers: [.no, .yes, .no, .no, .no]
        )
        XCTAssertEqual(result.totalPoints, 2)
        XCTAssertTrue(result.hasObservedPause)
        XCTAssertEqual(result.riskLevel, .high)
    }

    func testHighRiskWhenScoreSixOrMore() {
        let result = QuickCheckCalculator.evaluate(
            answers: [.yes, .no, .yes, .yes, .no]
        )
        XCTAssertEqual(result.totalPoints, 6)
        XCTAssertEqual(result.riskLevel, .high)
    }
}
