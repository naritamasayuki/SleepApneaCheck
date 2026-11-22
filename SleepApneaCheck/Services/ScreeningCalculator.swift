import Foundation

/// STOP-Bang および ESS スコアを計算する純粋ロジッククラス
enum ScreeningCalculator {

    /// 身長(cm)と体重(kg)からBMIを算出する（不正値の場合は nil）
    static func calculateBMI(heightCm: Double, weightKg: Double) -> Double? {
        guard heightCm > 30, heightCm < 300, weightKg > 10, weightKg < 500 else {
            return nil
        }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    /// STOP-Bang の「Yes」合計点数（0〜8）を算出する
    static func stopBangScore(from input: StopBangInput) -> Int {
        let flags = [
            input.snoring,
            input.tired,
            input.observed,
            input.highBloodPressure,
            input.bmiOver35,
            input.ageOver50,
            input.neckOver40,
            input.isMale
        ]
        return flags.filter { $0 }.count
    }

    /// STOP-Bang 基準に基づくリスクレベルを判定する
    /// - 高リスク: 合計5点以上、または STOP(最初の4項目)のうち2点以上 + (男性 or BMI>35 or 首周り>40cm)
    /// - 中リスク: 合計3〜4点
    /// - 低リスク: 合計0〜2点
    static func evaluateRiskLevel(from input: StopBangInput) -> ApneaRiskLevel {
        let total = stopBangScore(from: input)
        if total >= 5 {
            return .high
        }

        let stopPartScore = [
            input.snoring,
            input.tired,
            input.observed,
            input.highBloodPressure
        ].filter { $0 }.count

        let hasHighRiskModifier = input.isMale || input.bmiOver35 || input.neckOver40
        if stopPartScore >= 2 && hasHighRiskModifier {
            return .high
        }

        if total >= 3 {
            return .intermediate
        }

        return .low
    }

    /// ESS の合計点数（0〜24）を算出する
    static func essScore(from answers: [Int]) -> Int {
        answers.prefix(EssQuestion.allCases.count)
            .map { max(0, min(3, $0)) }
            .reduce(0, +)
    }

    /// ESS の合計点数から日中の眠気レベルを判定する
    static func evaluateSleepinessLevel(essScore: Int) -> DaytimeSleepinessLevel {
        switch essScore {
        case 0...10:
            return .normal
        case 11...15:
            return .mildExcessive
        default:
            return .severeExcessive
        }
    }

    /// 問診入力一式から総合結果オブジェクトを生成する
    static func evaluate(
        stopBangInput: StopBangInput,
        essAnswers: [Int],
        date: Date = Date()
    ) -> ScreeningResult {
        let sbScore = stopBangScore(from: stopBangInput)
        let risk = evaluateRiskLevel(from: stopBangInput)
        let essTotal = essScore(from: essAnswers)
        let sleepiness = evaluateSleepinessLevel(essScore: essTotal)

        return ScreeningResult(
            date: date,
            stopBangScore: sbScore,
            essScore: essTotal,
            riskLevel: risk,
            sleepinessLevel: sleepiness,
            stopBangInput: stopBangInput,
            essAnswers: essAnswers
        )
    }
}
