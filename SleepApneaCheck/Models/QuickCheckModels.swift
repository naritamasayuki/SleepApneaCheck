import Foundation

/// 簡易判定の回答選択肢
enum QuickCheckAnswer: Int, CaseIterable, Identifiable, Codable, Sendable {
    case yes = 2
    case unsure = 1
    case no = 0

    var id: Int { rawValue }

    /// ローカライズされた選択肢ラベル
    var localizedTitle: String {
        switch self {
        case .yes:
            return String(localized: "quickcheck.answer.yes")
        case .unsure:
            return String(localized: "quickcheck.answer.unsure")
        case .no:
            return String(localized: "quickcheck.answer.no")
        }
    }
}

/// 簡易判定の5つの主要チェック項目
enum QuickCheckQuestion: Int, CaseIterable, Identifiable, Codable, Sendable {
    case loudSnoring = 0
    case breathingPauseObserved
    case daytimeSleepiness
    case morningHeadacheOrDryMouth
    case hypertensionOrObesity

    var id: Int { rawValue }

    /// ローカライズされた質問文
    var localizedPrompt: String {
        switch self {
        case .loudSnoring:
            return String(localized: "quickcheck.q1")
        case .breathingPauseObserved:
            return String(localized: "quickcheck.q2")
        case .daytimeSleepiness:
            return String(localized: "quickcheck.q3")
        case .morningHeadacheOrDryMouth:
            return String(localized: "quickcheck.q4")
        case .hypertensionOrObesity:
            return String(localized: "quickcheck.q5")
        }
    }
}

/// 簡易判定の結果
struct QuickCheckResult: Equatable, Identifiable, Sendable {
    let id = UUID()
    let totalPoints: Int
    let maxPoints: Int
    let riskLevel: ApneaRiskLevel
    let hasObservedPause: Bool
    let summaryMessage: String
}

/// 簡易判定の計算ロジック
enum QuickCheckCalculator {
    /// 回答配列（5問）から簡易判定結果を算出する
    /// - 呼吸停止の指摘が「はい」の場合、または合計6点以上は高リスク傾向
    /// - 合計3〜5点は中リスク傾向（要経過観察）
    /// - 0〜2点は低リスク傾向
    static func evaluate(answers: [QuickCheckAnswer]) -> QuickCheckResult {
        let clamped = Array(answers.prefix(QuickCheckQuestion.allCases.count))
        let totalPoints = clamped.map(\.rawValue).reduce(0, +)
        let maxPoints = QuickCheckQuestion.allCases.count * QuickCheckAnswer.yes.rawValue
        let hasObservedPause = clamped.count > QuickCheckQuestion.breathingPauseObserved.rawValue
            && clamped[QuickCheckQuestion.breathingPauseObserved.rawValue] == .yes

        let risk: ApneaRiskLevel
        let summary: String
        if hasObservedPause || totalPoints >= 6 {
            risk = .high
            summary = String(localized: "quickcheck.result.high_summary")
        } else if totalPoints >= 3 {
            risk = .intermediate
            summary = String(localized: "quickcheck.result.intermediate_summary")
        } else {
            risk = .low
            summary = String(localized: "quickcheck.result.low_summary")
        }

        return QuickCheckResult(
            totalPoints: totalPoints,
            maxPoints: maxPoints,
            riskLevel: risk,
            hasObservedPause: hasObservedPause,
            summaryMessage: summary
        )
    }
}
