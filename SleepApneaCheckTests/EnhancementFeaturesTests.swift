import XCTest
@testable import SleepApneaCheck

final class EnhancementFeaturesTests: XCTestCase {

    func testDoctorReportPDFGenerationCreatesValidPDF() throws {
        let screening = ScreeningCalculator.evaluate(
            stopBangInput: StopBangInput(snoring: true, tired: true, isMale: true),
            essAnswers: [1, 2, 1, 1, 2, 0, 1, 0]
        )
        var session = AudioAnalyzer.generateSimulatedSession()
        session.tags = [.sidePillow, .mouthTape]

        let url = ReportExportService.generateDoctorReportPDF(
            screenings: [screening],
            audioSessions: [session]
        )
        XCTAssertNotNil(url)
        let data = try Data(contentsOf: url!)
        // PDF ヘッダ "%PDF" が含まれることを検証
        let header = String(data: data.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
        try? FileManager.default.removeItem(at: url!)
    }

    func testReviewPromptMilestonesAndCooldown() {
        let suiteName = "ReviewPromptTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        // 1回目・2回目は表示しない、3回目で表示
        XCTAssertFalse(ReviewPromptService.recordActionAndShouldPrompt(defaults: defaults, now: baseDate))
        XCTAssertFalse(ReviewPromptService.recordActionAndShouldPrompt(defaults: defaults, now: baseDate))
        XCTAssertTrue(ReviewPromptService.recordActionAndShouldPrompt(defaults: defaults, now: baseDate))

        // 4〜9回目は表示しない
        for _ in 4...9 {
            XCTAssertFalse(ReviewPromptService.recordActionAndShouldPrompt(defaults: defaults, now: baseDate))
        }

        // 10回目でも30日以内ならクールダウンで表示しない
        let withinCooldown = baseDate.addingTimeInterval(5 * 24 * 3600)
        XCTAssertFalse(ReviewPromptService.recordActionAndShouldPrompt(defaults: defaults, now: withinCooldown))
    }

    func testSleepAudioSessionBackwardCompatibleDecodeWithoutTags() throws {
        // 旧バージョン JSON（tags キーなし）でもクラッシュせず空配列として復号できること
        let legacyJSON = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "recordedAt": "2026-11-22T00:00:00Z",
          "durationSeconds": 60,
          "events": [],
          "normalizedLevels": [0.1, 0.2],
          "snoringDurationSeconds": 5,
          "apneaPauseCount": 1,
          "longestPauseSeconds": 12,
          "isSimulated": true
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SleepAudioSession.self, from: Data(legacyJSON.utf8))
        XCTAssertTrue(decoded.tags.isEmpty)
        XCTAssertEqual(decoded.apneaPauseCount, 1)
    }
}
