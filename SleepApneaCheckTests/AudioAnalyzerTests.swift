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

    func testEightHourWindowDecibelsCompletesEfficiently() {
        // 8時間（28,800秒）分の1秒窓dB配列でも安全かつ高速に解析できること
        var windows = [Double](repeating: -68.0, count: 28_800)
        // 300秒ごとに5秒いびき → 12秒静寂 → 3秒再開音 を10回配置
        for cycle in 0..<10 {
            let base = 100 + cycle * 300
            for s in base..<(base + 5) { windows[s] = -25.0 }
            for s in (base + 17)..<(base + 20) { windows[s] = -22.0 }
        }

        let session = AudioAnalyzer.analyzeWindowDecibels(
            windows,
            totalDuration: 28_800,
            sensitivity: .standard,
            isSimulated: false
        )
        XCTAssertEqual(session.durationSeconds, 28_800, accuracy: 0.1)
        XCTAssertEqual(session.apneaPauseCount, 10)
        XCTAssertEqual(session.normalizedLevels.count, 60)
    }

    func testSingleOneSecondNoiseDoesNotTriggerFalseApneaPause() {
        // 単発1秒の物音 → 12秒静寂 → 単発音 は無呼吸候補として誤検出しないこと
        var windows = [Double](repeating: -70.0, count: 30)
        windows[2] = -20.0
        windows[15] = -20.0

        let session = AudioAnalyzer.analyzeWindowDecibels(
            windows,
            totalDuration: 30,
            sensitivity: .standard,
            isSimulated: false
        )
        XCTAssertEqual(session.apneaPauseCount, 0)
    }

    func testShortRealRecordingDoesNotReturnHighRisk() {
        // 短い実録音（60秒）で1回無呼吸候補があっても、1時間換算による高リスク誤判定をしないこと
        var windows = [Double](repeating: -70.0, count: 60)
        for s in 2..<6 { windows[s] = -22.0 }
        for s in 26..<30 { windows[s] = -22.0 } // 20秒ポーズ

        let session = AudioAnalyzer.analyzeWindowDecibels(
            windows,
            totalDuration: 60,
            sensitivity: .standard,
            isSimulated: false
        )
        XCTAssertTrue(session.isShortRecording)
        XCTAssertNotEqual(session.audioRiskCategory, .high)
    }

    func testQuietBreathingAfterSingleEarlySnoreIsNotCountedRepeatedly() {
        // 宵の口に3秒のいびき → 以後は「30秒の静寂＋1秒の物音」が10回続く夜でも誤検出を繰り返さないこと
        let sampleRate = 1000.0
        var samples: [Float] = []
        func append(seconds: Int, amplitude: Float) {
            samples += [Float](repeating: amplitude, count: Int(sampleRate) * seconds)
        }
        append(seconds: 3, amplitude: 0.05)
        for _ in 0..<10 {
            append(seconds: 30, amplitude: 0.0005)
            append(seconds: 1, amplitude: 0.05)
        }
        let session = AudioAnalyzer.analyzeSamples(samples, sampleRate: sampleRate)
        XCTAssertLessThanOrEqual(session.apneaPauseCount, 1)
    }
}
