import AVFoundation
import Combine
import Foundation
import os

/// マイク録音・音声再生エラー
enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case sessionSetupFailed(Error)
    case recorderStartFailed(Error)
    case playbackFailed(Error)
    case noRecordingFile

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "error.mic.permission_denied")
        case .sessionSetupFailed:
            return String(localized: "error.mic.session_failed")
        case .recorderStartFailed:
            return String(localized: "error.mic.start_failed")
        case .playbackFailed:
            return String(localized: "error.audio.playback_failed")
        case .noRecordingFile:
            return String(localized: "error.audio.no_file")
        }
    }
}

/// 睡眠音声の録音および再生を管理するサービス
@MainActor
final class AudioRecorderService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var currentMeterLevel: Double = 0.0
    @Published private(set) var permissionGranted: Bool?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var currentRecordingURL: URL?
    private var meterTimer: Timer?
    private var maxDurationLimit: TimeInterval?
    private var onAutoStopLimitReached: ((URL) -> Void)?

    private let logger = Logger(subsystem: "com.sleepapneacheck.app", category: "AudioRecorderService")

    /// マイク使用権限を確認・要求する
    func requestPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionGranted = granted
        return granted
    }

    /// 録音を開始する
    func startRecording(
        in directoryURL: URL,
        maxDurationSeconds: TimeInterval? = nil,
        onLimitReached: ((URL) -> Void)? = nil
    ) async throws {
        let granted = await requestPermission()
        guard granted else {
            throw AudioRecorderError.permissionDenied
        }

        stopPlayback()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            logger.error("AVAudioSession設定失敗: \(error.localizedDescription)")
            throw AudioRecorderError.sessionSetupFailed(error)
        }

        let fileName = "sleep_\(Int(Date().timeIntervalSince1970)).m4a"
        let fileURL = directoryURL.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            newRecorder.isMeteringEnabled = true
            guard newRecorder.record() else {
                throw AudioRecorderError.recorderStartFailed(
                    NSError(domain: "AudioRecorderService", code: -1)
                )
            }
            recorder = newRecorder
            currentRecordingURL = fileURL
            elapsedSeconds = 0
            currentMeterLevel = 0
            maxDurationLimit = maxDurationSeconds
            onAutoStopLimitReached = onLimitReached
            isRecording = true
            startMeteringTimer()
        } catch {
            logger.error("録音開始失敗: \(error.localizedDescription)")
            throw AudioRecorderError.recorderStartFailed(error)
        }
    }

    /// 録音を停止し、保存されたファイルURLを返す
    func stopRecording() -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil

        recorder?.stop()
        recorder = nil
        isRecording = false
        currentMeterLevel = 0

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.warning("AVAudioSession非アクティブ化エラー: \(error.localizedDescription)")
        }

        return currentRecordingURL
    }

    /// 指定された録音ファイルを再生する
    func togglePlayback(url: URL) throws {
        if isPlaying {
            stopPlayback()
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioRecorderError.noRecordingFile
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.play()
            player = audioPlayer
            isPlaying = true
        } catch {
            logger.error("音声再生失敗: \(error.localizedDescription)")
            throw AudioRecorderError.playbackFailed(error)
        }
    }

    /// 再生を停止する
    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            self?.player = nil
        }
    }

    private func startMeteringTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.recorder, self.isRecording else { return }
                recorder.updateMeters()
                let power = Double(recorder.averagePower(forChannel: 0))
                // -60dB〜0dB を 0.0〜1.0 に正規化
                let normalized = max(0.0, min(1.0, (power + 60.0) / 60.0))
                self.currentMeterLevel = normalized
                self.elapsedSeconds = recorder.currentTime

                if let limit = self.maxDurationLimit, self.elapsedSeconds >= limit {
                    if let url = self.stopRecording() {
                        self.onAutoStopLimitReached?(url)
                    }
                }
            }
        }
    }
}
