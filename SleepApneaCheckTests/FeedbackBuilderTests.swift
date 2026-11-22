import XCTest
@testable import SleepApneaCheck

final class FeedbackBuilderTests: XCTestCase {

    func testMakeSubjectUsesPrefixAndFallback() {
        let withCustom = FeedbackBuilder.makeSubject(category: .bugReport, customSubject: "録音ボタンが反応しない")
        XCTAssertEqual(withCustom, "[Bug] 録音ボタンが反応しない")

        let emptyCustom = FeedbackBuilder.makeSubject(category: .featureRequest, customSubject: "   ")
        XCTAssertTrue(emptyCustom.hasPrefix("[Feature] SleepApnea Check"))
    }

    func testMakeBodyIncludesAndExcludesDeviceInfo() {
        let withInfo = FeedbackBuilder.makeBody(
            category: .bugReport,
            message: "グラフ表示がずれる",
            includeDeviceInfo: true,
            appVersion: "1.1.0",
            buildNumber: "2",
            osVersion: "18.0",
            localeIdentifier: "ja_JP"
        )
        XCTAssertTrue(withInfo.contains("グラフ表示がずれる"))
        XCTAssertTrue(withInfo.contains("App Version: 1.1.0 (2)"))
        XCTAssertTrue(withInfo.contains("OS: iOS 18.0"))
        XCTAssertTrue(withInfo.contains("Locale: ja_JP"))

        let withoutInfo = FeedbackBuilder.makeBody(
            category: .general,
            message: "使いやすいです",
            includeDeviceInfo: false,
            appVersion: "1.1.0",
            buildNumber: "2",
            osVersion: "18.0",
            localeIdentifier: "ja_JP"
        )
        XCTAssertTrue(withoutInfo.contains("使いやすいです"))
        XCTAssertFalse(withoutInfo.contains("App Version:"))
    }

    func testURLGeneration() {
        let ghURL = FeedbackBuilder.makeGitHubIssueURL(
            category: .featureRequest,
            subject: "[Feature] Dark mode",
            body: "Please add dark mode"
        )
        XCTAssertNotNil(ghURL)
        XCTAssertTrue(ghURL?.absoluteString.contains("github.com/naritamasayuki/SleepApneaCheck/issues/new") == true)
        XCTAssertTrue(ghURL?.absoluteString.contains("labels=enhancement") == true)

        let mailURL = FeedbackBuilder.makeMailtoURL(subject: "[Bug] Test", body: "Detail")
        XCTAssertNotNil(mailURL)
        XCTAssertEqual(mailURL?.scheme, "mailto")
    }
}
