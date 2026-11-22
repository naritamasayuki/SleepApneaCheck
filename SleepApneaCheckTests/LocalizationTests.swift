import XCTest
@testable import SleepApneaCheck

final class LocalizationTests: XCTestCase {

    func testLocalizedEnumsDoNotReturnRawKeys() {
        for question in EssQuestion.allCases {
            XCTAssertFalse(question.localizedPrompt.isEmpty)
            XCTAssertFalse(question.localizedPrompt.hasPrefix("ess.q"))
        }
        for option in EssScoreOption.allCases {
            XCTAssertFalse(option.localizedTitle.isEmpty)
            XCTAssertFalse(option.localizedTitle.hasPrefix("ess.option."))
        }
        for risk in ApneaRiskLevel.allCases {
            XCTAssertFalse(risk.localizedTitle.hasPrefix("risk."))
            XCTAssertFalse(risk.localizedAdvice.hasPrefix("risk."))
        }
        for sensitivity in AudioSensitivity.allCases {
            XCTAssertFalse(sensitivity.localizedTitle.hasPrefix("settings.sensitivity."))
        }
        for question in QuickCheckQuestion.allCases {
            XCTAssertFalse(question.localizedPrompt.isEmpty)
            XCTAssertFalse(question.localizedPrompt.hasPrefix("quickcheck.q"))
        }
        for answer in QuickCheckAnswer.allCases {
            XCTAssertFalse(answer.localizedTitle.isEmpty)
            XCTAssertFalse(answer.localizedTitle.hasPrefix("quickcheck.answer."))
        }
    }
}
