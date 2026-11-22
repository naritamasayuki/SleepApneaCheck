import Foundation
import os
import SwiftUI

/// アプリ全体の状態管理と履歴永続化を担うストア
@MainActor
final class AppState: ObservableObject {
    @Published var screenings: [ScreeningResult] = []
    @Published var audioSessions: [SleepAudioSession] = []
    @Published var sensitivity: AudioSensitivity {
        didSet {
            UserDefaults.standard.set(sensitivity.rawValue, forKey: Self.sensitivityKey)
        }
    }
    @Published var alertErrorMessage: String?

    let repository: HistoryRepository
    private static let sensitivityKey = "audio_analysis_sensitivity"
    private let logger = Logger(subsystem: "com.sleepapneacheck.app", category: "AppState")

    init(repository: HistoryRepository = HistoryRepository()) {
        self.repository = repository
        let savedSensitivity = UserDefaults.standard.string(forKey: Self.sensitivityKey)
        self.sensitivity = savedSensitivity.flatMap(AudioSensitivity.init(rawValue:)) ?? .standard
        loadHistory()
    }

    /// 履歴を読み込む
    func loadHistory() {
        do {
            let store = try repository.load()
            screenings = store.screenings.sorted { $0.date > $1.date }
            audioSessions = store.audioSessions.sorted { $0.recordedAt > $1.recordedAt }
        } catch {
            logger.error("履歴読み込みエラー: \(error.localizedDescription)")
            alertErrorMessage = error.localizedDescription
        }
    }

    /// 問診結果を保存する
    func addScreeningResult(_ result: ScreeningResult) {
        screenings.insert(result, at: 0)
        persistHistory()
    }

    /// 睡眠録音解析結果を保存する
    func addAudioSession(_ session: SleepAudioSession) {
        audioSessions.insert(session, at: 0)
        persistHistory()
    }

    /// 問診結果を削除する
    func deleteScreening(at offsets: IndexSet) {
        screenings.remove(atOffsets: offsets)
        persistHistory()
    }

    /// 睡眠録音セッションを削除する（関連音声ファイルも削除）
    func deleteAudioSession(at offsets: IndexSet) {
        for index in offsets {
            let session = audioSessions[index]
            repository.deleteAudioFile(named: session.audioFileName)
        }
        audioSessions.remove(atOffsets: offsets)
        persistHistory()
    }

    /// 全履歴を削除する
    func clearAllHistory() {
        do {
            try repository.clearAll()
            screenings = []
            audioSessions = []
        } catch {
            logger.error("履歴削除エラー: \(error.localizedDescription)")
            alertErrorMessage = error.localizedDescription
        }
    }

    private func persistHistory() {
        do {
            let store = HistoryStoreData(screenings: screenings, audioSessions: audioSessions)
            try repository.save(store)
        } catch {
            logger.error("履歴保存エラー: \(error.localizedDescription)")
            alertErrorMessage = error.localizedDescription
        }
    }
}

@main
struct SleepApneaCheckApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var notificationService = NotificationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(subscriptionService)
                .environmentObject(notificationService)
        }
    }
}
