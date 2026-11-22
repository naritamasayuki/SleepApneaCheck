import Foundation

/// STOP-Bang 質問票の入力データ
struct StopBangInput: Codable, Equatable, Sendable {
    var snoring: Bool = false
    var tired: Bool = false
    var observed: Bool = false
    var highBloodPressure: Bool = false
    var bmiOver35: Bool = false
    var ageOver50: Bool = false
    var neckOver40: Bool = false
    var isMale: Bool = false

    /// 身長(cm)と体重(kg)からBMIを計算し、35超えフラグを更新するための補助値（任意）
    var heightCm: Double?
    var weightKg: Double?
}

/// エプワース眠気尺度 (ESS) の各質問項目（0〜3点）
enum EssScoreOption: Int, Codable, CaseIterable, Identifiable, Sendable {
    case never = 0
    case slight = 1
    case moderate = 2
    case high = 3

    var id: Int { rawValue }

    /// ローカライズされた選択肢ラベル
    var localizedTitle: String {
        switch self {
        case .never:
            return String(localized: "ess.option.never")
        case .slight:
            return String(localized: "ess.option.slight")
        case .moderate:
            return String(localized: "ess.option.moderate")
        case .high:
            return String(localized: "ess.option.high")
        }
    }
}

/// エプワース眠気尺度 (ESS) の8項目の質問
enum EssQuestion: Int, CaseIterable, Identifiable, Codable, Sendable {
    case sittingReading = 0
    case watchingTV
    case sittingInactivePublic
    case passengerInCar
    case lyingDownAfternoon
    case sittingTalking
    case sittingQuietlyAfterLunch
    case inCarStoppedTraffic

    var id: Int { rawValue }

    /// ローカライズされた質問文
    var localizedPrompt: String {
        switch self {
        case .sittingReading:
            return String(localized: "ess.q1")
        case .watchingTV:
            return String(localized: "ess.q2")
        case .sittingInactivePublic:
            return String(localized: "ess.q3")
        case .passengerInCar:
            return String(localized: "ess.q4")
        case .lyingDownAfternoon:
            return String(localized: "ess.q5")
        case .sittingTalking:
            return String(localized: "ess.q6")
        case .sittingQuietlyAfterLunch:
            return String(localized: "ess.q7")
        case .inCarStoppedTraffic:
            return String(localized: "ess.q8")
        }
    }
}

/// 閉塞性睡眠時無呼吸症候群（OSA）のリスクレベル
enum ApneaRiskLevel: String, Codable, CaseIterable, Sendable {
    case low
    case intermediate
    case high

    /// ローカライズされたリスク名称
    var localizedTitle: String {
        switch self {
        case .low:
            return String(localized: "risk.low.title")
        case .intermediate:
            return String(localized: "risk.intermediate.title")
        case .high:
            return String(localized: "risk.high.title")
        }
    }

    /// ローカライズされたアドバイス文
    var localizedAdvice: String {
        switch self {
        case .low:
            return String(localized: "risk.low.advice")
        case .intermediate:
            return String(localized: "risk.intermediate.advice")
        case .high:
            return String(localized: "risk.high.advice")
        }
    }
}

/// 日中の眠気レベル（ESSに基づく分類）
enum DaytimeSleepinessLevel: String, Codable, Sendable {
    case normal
    case mildExcessive
    case severeExcessive

    /// ローカライズされた眠気レベルの名称
    var localizedTitle: String {
        switch self {
        case .normal:
            return String(localized: "ess.level.normal")
        case .mildExcessive:
            return String(localized: "ess.level.mild")
        case .severeExcessive:
            return String(localized: "ess.level.severe")
        }
    }
}

/// 問診スクリーニングの総合評価結果
struct ScreeningResult: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let stopBangScore: Int
    let essScore: Int
    let riskLevel: ApneaRiskLevel
    let sleepinessLevel: DaytimeSleepinessLevel
    let stopBangInput: StopBangInput
    let essAnswers: [Int]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        stopBangScore: Int,
        essScore: Int,
        riskLevel: ApneaRiskLevel,
        sleepinessLevel: DaytimeSleepinessLevel,
        stopBangInput: StopBangInput,
        essAnswers: [Int]
    ) {
        self.id = id
        self.date = date
        self.stopBangScore = stopBangScore
        self.essScore = essScore
        self.riskLevel = riskLevel
        self.sleepinessLevel = sleepinessLevel
        self.stopBangInput = stopBangInput
        self.essAnswers = essAnswers
    }
}
