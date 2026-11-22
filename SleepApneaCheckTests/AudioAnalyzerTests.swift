import XCTest
@testable import SleepApneaCheck

final class AudioAnalyzerTests: XCTestCase {

    func testAnalyzeEmptySamplesReturnsEmptySession() {
        let session = AudioAnalyzer.analyzeSamples([], sampleRate: 8000)
        XCTAssertEqual(session.durationSeconds, 0)
        XCTAssertEqual(session.apneaPauseCount, 0)
        XCTAssertTrue(session.events.isEmpty)
        XCTAssertEqual(session.audioRiskCategory, .low)
    }

    func testAnalyzeSynthesizedApneaPatternDetectsSnoringAndPauses() {
        let session = AudioAnalyzer.generateSimulatedSession(sensitivity: .standard)
        XCTAssertEqual(session.durationSeconds, 60, accuracy: 0.1)
        XCTAssertTrue(session.isSimulated)
        XCTAssertGreaterThanOrEqual(session.apneaPauseCount, 2)
        XCTAssertGreaterThan(session.snoringDurationSeconds, 5)
        XCTAssertGreaterThanOrEqual(session.longestPauseSeconds, 10)
        XCTAssertFalse(session.normalizedLevels.isEmpty)
    }

    func testShortSilenceIsNotCountedAsApneaPause() {
        // 5秒の静寂（10秒未満）は無呼吸候補としてカウントされないこと
        let sampleRate = 1000.0
        let totalSeconds = 20
        var samples = [Float](repeating: 0.0005, count: Int(sampleRate) * totalSeconds)

        // 0〜5秒、10〜20秒に大きめの音を入れる（間の静寂は5秒のみ）
        for sec in Array(0..<5) + Array(10..<20) {
            let start = sec * Int(sampleRate)
            for i in start..<(start + Int(sampleRate)) {
                samples[i] = 0.3 * sin(Float(i) * 0.1)
            }
        }

        let session = AudioAnalyzer.analyzeSamples(samples, sampleRate: sampleRate)
        XCTAssertEqual(session.apneaPauseCount, 0)
    }
}
