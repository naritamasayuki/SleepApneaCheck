import Foundation

/// 履歴保存用の統合データコンテナ
struct HistoryStoreData: Codable, Equatable, Sendable {
    var screenings: [ScreeningResult]
    var audioSessions: [SleepAudioSession]

    init(screenings: [ScreeningResult] = [], audioSessions: [SleepAudioSession] = []) {
        self.screenings = screenings
        self.audioSessions = audioSessions
    }
}
