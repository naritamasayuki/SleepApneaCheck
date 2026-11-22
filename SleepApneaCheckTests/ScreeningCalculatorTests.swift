import XCTest
@testable import SleepApneaCheck

final class ScreeningCalculatorTests: XCTestCase {

    func testCalculateBMI_ValidAndInvalidInputs() {
        let bmi = ScreeningCalculator.calculateBMI(heightCm: 170, weightKg: 70)
        XCTAssertNotNil(bmi)
        XCTAssertEqual(bmi ?? 0, 24.22, accuracy: 0.05)

        XCTAssertNil(ScreeningCalculator.calculateBMI(heightCm: 0, weightKg: 70))
        XCTAssertNil(ScreeningCalculator.calculateBMI(heightCm: 170, weightKg: -5))
    }

    func testStopBangRiskLevels() {
        // 低リスク (0〜2点)
        let lowInput = StopBangInput(snoring: true, tired: true)
        XCTAssertEqual(ScreeningCalculator.stopBangScore(from: lowInput), 2)
        XCTAssertEqual(ScreeningCalculator.evaluateRiskLevel(from: lowInput), .low)

        // 中リスク (3〜4点、STOP>=2 + 修飾因子なし)
        let intermediateInput = StopBangInput(
            snoring: true,
            tired: true,
            observed: true,
            highBloodPressure: false,
            bmiOver35: false,
            ageOver50: false,
            neckOver40: false,
            isMale: false
        )
        XCTAssertEqual(ScreeningCalculator.stopBangScore(from: intermediateInput), 3)
        XCTAssertEqual(ScreeningCalculator.evaluateRiskLevel(from: intermediateInput), .intermediate)

        // 高リスク (STOP 2点 + 男性)
        let highByModifier = StopBangInput(
            snoring: true,
            tired: true,
            isMale: true
        )
        XCTAssertEqual(ScreeningCalculator.stopBangScore(from: highByModifier), 3)
        XCTAssertEqual(ScreeningCalculator.evaluateRiskLevel(from: highByModifier), .high)

        // 高リスク (合計5点以上)
        let highByTotal = StopBangInput(
            snoring: true,
            tired: true,
            observed: true,
            highBloodPressure: true,
            ageOver50: true
        )
        XCTAssertEqual(ScreeningCalculator.evaluateRiskLevel(from: highByTotal), .high)
    }

    func testEssScoringAndSleepinessLevels() {
        XCTAssertEqual(ScreeningCalculator.essScore(from: [0, 1, 2, 3, 0, 1, 2, 1]), 10)
        XCTAssertEqual(ScreeningCalculator.evaluateSleepinessLevel(essScore: 10), .normal)
        XCTAssertEqual(ScreeningCalculator.evaluateSleepinessLevel(essScore: 11), .mildExcessive)
        XCTAssertEqual(ScreeningCalculator.evaluateSleepinessLevel(essScore: 16), .severeExcessive)

        // 範囲外の値や回答不足がクランプされること
        XCTAssertEqual(ScreeningCalculator.essScore(from: [-1, 5, 2]), 5)
    }
}
