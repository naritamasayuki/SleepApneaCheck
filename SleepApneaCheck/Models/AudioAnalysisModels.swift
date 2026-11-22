import Foundation

/// 睡眠録音中に検出されたイベント種別
enum SleepAudioEventType: String, Codable, Sendable {
    case snoring
    case apneaPause

    /// ローカライズされたイベント名称
    var localizedTitle: String {
        switch self {
        case .snoring:
            return String(localized: "audio.event.snoring")
        case .apneaPause:
            return String(localized: "audio.event.apnea_pause")
        }
    }
}

/// 検出された個別音声イベント
struct SleepAudioEvent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let type: SleepAudioEventType
    /// 録音開始からの経過秒数
    let startOffsetSeconds: TimeInterval
    /// イベント継続時間（秒）
    let durationSeconds: TimeInterval
    /// ピーク相対音圧 (dBFS相当, -100.0〜0.0)
    let peakDecibels: Double

    init(
        id: UUID = UUID(),
        type: SleepAudioEventType,
        startOffsetSeconds: TimeInterval,
        durationSeconds: TimeInterval,
        peakDecibels: Double
    ) {
        self.id = id
        self.type = type
        self.startOffsetSeconds = startOffsetSeconds
        self.durationSeconds = durationSeconds
        self.peakDecibels = peakDecibels
    }
}

/// 音声解析の感度設定
enum AudioSensitivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case standard
    case high

    var id: String { rawValue }

    /// ローカライズされた感度名
    var localizedTitle: String {
        switch self {
        case .low:
            return String(localized: "settings.sensitivity.low")
        case .standard:
            return String(localized: "settings.sensitivity.standard")
        case .high:
            return String(localized: "settings.sensitivity.high")
        }
    }

    /// いびき検出のノイズフロアからのしきい値オフセット (dB)
    var snoringThresholdOffsetDb: Double {
        switch self {
        case .low: return 16.0
        case .standard: return 12.0
        case .high: return 8.0
        }
    }
}

/// 睡眠録音セッションの解析結果
struct SleepAudioSession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let recordedAt: Date
    let durationSeconds: TimeInterval
    let audioFileName: String?
    let events: [SleepAudioEvent]
    /// タイムライン表示用の正規化音量レベル配列 (0.0〜1.0)
    let normalizedLevels: [Double]
    let snoringDurationSeconds: TimeInterval
    let apneaPauseCount: Int
    let longestPauseSeconds: TimeInterval
    let isSimulated: Bool

    /// 1時間あたりの推定無呼吸候補イベント数（簡易指標）
    var estimatedEventsPerHour: Double {
        guard durationSeconds > 0 else { return 0 }
        return Double(apneaPauseCount) / (durationSeconds / 3600.0)
    }

    /// 録音全体に対するいびき時間の割合 (0.0〜100.0%)
    var snoringPercentage: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(100.0, (snoringDurationSeconds / durationSeconds) * 100.0)
    }

    /// 簡易的な音声所見リスク評価
    var audioRiskCategory: ApneaRiskLevel {
        let index = estimatedEventsPerHour
        if index >= 15 || longestPauseSeconds >= 20 {
            return .high
        } else if index >= 5 || snoringPercentage >= 25 {
            return .intermediate
        } else {
            return .low
        }
    }

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        durationSeconds: TimeInterval,
        audioFileName: String? = nil,
        events: [SleepAudioEvent],
        normalizedLevels: [Double],
        snoringDurationSeconds: TimeInterval,
        apneaPauseCount: Int,
        longestPauseSeconds: TimeInterval,
        isSimulated: Bool = false
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.durationSeconds = durationSeconds
        self.audioFileName = audioFileName
        self.events = events
        self.normalizedLevels = normalizedLevels
        self.snoringDurationSeconds = snoringDurationSeconds
        self.apneaPauseCount = apneaPauseCount
        self.longestPauseSeconds = longestPauseSeconds
        self.isSimulated = isSimulated
    }
}
