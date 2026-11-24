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

/// 睡眠時の状況・対策グッズタグ（効果比較用）
enum SleepCareTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case sidePillow
    case mouthTape
    case nasalStrips
    case mouthpiece
    case alcohol
    case heavyFatigue

    var id: String { rawValue }

    /// ローカライズされたタグ名
    var localizedTitle: String {
        switch self {
        case .sidePillow: return String(localized: "tag.side_pillow")
        case .mouthTape: return String(localized: "tag.mouth_tape")
        case .nasalStrips: return String(localized: "tag.nasal_strips")
        case .mouthpiece: return String(localized: "tag.mouthpiece")
        case .alcohol: return String(localized: "tag.alcohol")
        case .heavyFatigue: return String(localized: "tag.heavy_fatigue")
        }
    }

    /// SF Symbols アイコン名
    var symbolName: String {
        switch self {
        case .sidePillow: return "bed.double.fill"
        case .mouthTape: return "bandage.fill"
        case .nasalStrips: return "wind"
        case .mouthpiece: return "mouth.fill"
        case .alcohol: return "wineglass.fill"
        case .heavyFatigue: return "battery.25"
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
    /// 就寝時の対策・状況タグ
    var tags: [SleepCareTag]
    /// 起床時の熟睡感評価（1〜5、未入力は nil）
    var morningRating: Int?
    /// 起床時のひとことメモ
    var note: String

    enum CodingKeys: String, CodingKey {
        case id, recordedAt, durationSeconds, audioFileName, events, normalizedLevels
        case snoringDurationSeconds, apneaPauseCount, longestPauseSeconds, isSimulated
        case tags, morningRating, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        durationSeconds = try container.decode(TimeInterval.self, forKey: .durationSeconds)
        audioFileName = try container.decodeIfPresent(String.self, forKey: .audioFileName)
        events = try container.decode([SleepAudioEvent].self, forKey: .events)
        normalizedLevels = try container.decode([Double].self, forKey: .normalizedLevels)
        snoringDurationSeconds = try container.decode(TimeInterval.self, forKey: .snoringDurationSeconds)
        apneaPauseCount = try container.decode(Int.self, forKey: .apneaPauseCount)
        longestPauseSeconds = try container.decode(TimeInterval.self, forKey: .longestPauseSeconds)
        isSimulated = try container.decode(Bool.self, forKey: .isSimulated)
        // 旧バージョン保存データとの後方互換性を維持
        tags = try container.decodeIfPresent([SleepCareTag].self, forKey: .tags) ?? []
        morningRating = try container.decodeIfPresent(Int.self, forKey: .morningRating)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    /// 競合定番の「いびきスコア (0〜100)」を算出する（値が大きいほどいびき・呼吸乱れが強い）
    var snoreScore: Int {
        guard durationSeconds > 0 else { return 0 }
        // いびき時間割合（最大55点）＋1時間あたり無呼吸候補（最大35点）＋強大いびきピーク補正（最大10点）
        let ratioScore = min(55.0, snoringPercentage * 0.9)
        let apneaScore = min(35.0, estimatedEventsPerHour * 1.5)
        let peakSnoreDb = events
            .filter { $0.type == .snoring }
            .map(\.peakDecibels)
            .max() ?? -60.0
        let intensityBonus = peakSnoreDb > -25.0 ? 10.0 : (peakSnoreDb > -35.0 ? 5.0 : 0.0)
        return min(100, max(0, Int((ratioScore + apneaScore + intensityBonus).rounded())))
    }

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
        isSimulated: Bool = false,
        tags: [SleepCareTag] = [],
        morningRating: Int? = nil,
        note: String = ""
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
        self.tags = tags
        self.morningRating = morningRating
        self.note = note
    }
}
