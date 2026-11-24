import XCTest
@testable import SleepApneaCheck

final class RemedyAnalyticsTests: XCTestCase {

    func testSnoreScoreCalculation() {
        let quietSession = SleepAudioSession(
            durationSeconds: 3600,
            events: [],
            normalizedLevels: [0.05],
            snoringDurationSeconds: 0,
            apneaPauseCount: 0,
            longestPauseSeconds: 0
        )
        XCTAssertEqual(quietSession.snoreScore, 0)

        let loudSession = SleepAudioSession(
            durationSeconds: 3600,
            events: [
                SleepAudioEvent(type: .snoring, startOffsetSeconds: 10, durationSeconds: 1200, peakDecibels: -18.0)
            ],
            normalizedLevels: [0.8],
            snoringDurationSeconds: 1800, // 50%
            apneaPauseCount: 20,          // 20/h
            longestPauseSeconds: 18
        )
        XCTAssertGreaterThanOrEqual(loudSession.snoreScore, 80)
        XCTAssertLessThanOrEqual(loudSession.snoreScore, 100)
    }

    func testRemedyAnalyticsDetectsImprovementAndWorsening() {
        // 横向き枕あり = 低スコア（改善）、飲酒あり = 高スコア（悪化）
        let pillowSession = SleepAudioSession(
            durationSeconds: 3600,
            events: [],
            normalizedLevels: [0.1],
            snoringDurationSeconds: 180,
            apneaPauseCount: 2,
            longestPauseSeconds: 10,
            tags: [.sidePillow]
        )
        let alcoholSession = SleepAudioSession(
            durationSeconds: 3600,
            events: [SleepAudioEvent(type: .snoring, startOffsetSeconds: 0, durationSeconds: 10, peakDecibels: -20)],
            normalizedLevels: [0.9],
            snoringDurationSeconds: 1800,
            apneaPauseCount: 18,
            longestPauseSeconds: 18,
            tags: [.alcohol]
        )

        let stats = RemedyAnalyticsService.analyze(sessions: [pillowSession, alcoholSession])
        XCTAssertEqual(stats.count, 2)

        // 改善幅が大きい（delta がマイナス）の横向き枕が先頭に来ること
        XCTAssertEqual(stats.first?.tag, .sidePillow)
        XCTAssertLessThan(stats.first?.scoreDelta ?? 0, 0)

        XCTAssertEqual(stats.last?.tag, .alcohol)
        XCTAssertGreaterThan(stats.last?.scoreDelta ?? 0, 0)
    }
}
