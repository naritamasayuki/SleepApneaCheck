import AVFoundation
import Combine
import Foundation
import os
import UIKit

/// マイク録音・音声再生エラー
enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case sessionSetupFailed(Error)
    case recorderStartFailed(Error)
    case playbackFailed(Error)
    case noRecordingFile
    case recordingInProgress

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
        case .recordingInProgress:
            return String(localized: "error.audio.recording_in_progress")
        }
    }
}

/// 睡眠音声の録音および再生を管理するサービス（アプリ全体で単一インスタンスを共有）
@MainActor
final class AudioRecorderService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var activeEventID: UUID?
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var currentMeterLevel: Double = 0.0
    @Published private(set) var permissionGranted: Bool?
    @Published private(set) var interruptionCount: Int = 0
    @Published private(set) var configuredDelaySeconds: TimeInterval = 0
    @Published private(set) var recordingStartedAt: Date?
    @Published private(set) var recordingGaps: [RecordingGap] = []

    /// 入眠待ちディレイの残り秒数（バックグラウンド録音セッション稼働中にカウントダウン）
    var remainingDelaySeconds: Int {
        guard isRecording, configuredDelaySeconds > 0 else { return 0 }
        return max(0, Int(ceil(configuredDelaySeconds - elapsedSeconds)))
    }

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var currentRecordingURL: URL?
    private var meterTimer: Timer?
    private var maxDurationLimit: TimeInterval?
    private var onAutoStopLimitReached: ((URL) -> Void)?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var interruptionBeganAt: Date?
    private var interruptionFileOffset: TimeInterval = 0
    /// フォアグラウンド 0.2 秒 / バックグラウンド 5 秒（省バッテリー化）
    private var meterInterval: TimeInterval = 0.2

    private let logger = Logger(subsystem: "com.sleepapneacheck.app", category: "AudioRecorderService")

    override init() {
        super.init()
        setupAudioSessionObservers()
        setupLifecycleObservers()
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// マイク使用権限を確認・要求する
    func requestPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionGranted = granted
        return granted
    }

    /// 録音を開始する（delaySeconds > 0 の場合も即座に録音セッションを開始しバックグラウンドを維持）
    func startRecording(
        in directoryURL: URL,
        delaySeconds: TimeInterval = 0,
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

        let startDate = Date()
        let fileName = "sleep_\(Int(startDate.timeIntervalSince1970)).m4a"
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
            recordingStartedAt = startDate
            configuredDelaySeconds = max(0, delaySeconds)
            interruptionCount = 0
            recordingGaps = []
            interruptionBeganAt = nil
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

    /// ディレイをスキップして今すぐ解析対象区間に切り替える
    func skipRemainingDelay() {
        guard isRecording else { return }
        configuredDelaySeconds = elapsedSeconds
    }

    /// 録音をキャンセルして一時ファイルを破棄する（ディレイ中のキャンセル等）
    func cancelRecordingAndDiscard() {
        let url = stopRecording()
        if let url, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
        configuredDelaySeconds = 0
        recordingStartedAt = nil
        interruptionCount = 0
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
        guard !isRecording else {
            throw AudioRecorderError.recordingInProgress
        }
        if isPlaying && activeEventID == nil {
            stopPlayback()
            return
        }
        try play(url: url, startingAt: 0, eventID: nil)
    }

    /// 指定秒数からピンポイント頭出し再生を行う（例：イベント開始5秒前）
    func play(url: URL, startingAt offsetSeconds: TimeInterval, eventID: UUID? = nil) throws {
        guard !isRecording else {
            throw AudioRecorderError.recordingInProgress
        }
        if isPlaying && activeEventID == eventID && eventID != nil {
            stopPlayback()
            return
        }

        stopPlayback()

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioRecorderError.noRecordingFile
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            let clampedOffset = max(0, min(offsetSeconds, max(0, audioPlayer.duration - 0.5)))
            audioPlayer.currentTime = clampedOffset
            audioPlayer.play()
            player = audioPlayer
            activeEventID = eventID
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
        activeEventID = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            self?.activeEventID = nil
            self?.player = nil
        }
    }

    /// 着信・アラーム・Siri等のオーディオ割り込みおよびBluetoothルート変更を監視し録音を自動再開する
    private func setupAudioSessionObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleRouteChange(reasonRaw: reasonRaw)
            }
        }
    }

    private func handleAudioInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard isRecording, let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
            return
        }
        switch type {
        case .began:
            interruptionCount += 1
            interruptionBeganAt = Date()
            interruptionFileOffset = recorder?.currentTime ?? elapsedSeconds
            logger.warning("録音中にオーディオ割り込みが発生しました（回数: \(self.interruptionCount)）")
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            if options.contains(.shouldResume) || recorder?.isRecording == false {
                resumeRecordingAfterInterruption()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonRaw: UInt?) {
        guard isRecording, let reasonRaw,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }
        if reason == .oldDeviceUnavailable || reason == .newDeviceAvailable {
            if recorder?.isRecording == false {
                interruptionCount += 1
                resumeRecordingAfterInterruption()
            }
        }
    }

    private func resumeRecordingAfterInterruption() {
        guard isRecording, let recorder else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            let resumed = recorder.record()
            if resumed, let began = interruptionBeganAt {
                recordingGaps.append(
                    RecordingGap(
                        fileOffsetSeconds: interruptionFileOffset,
                        durationSeconds: Date().timeIntervalSince(began)
                    )
                )
                interruptionBeganAt = nil
            }
            logger.info("割り込み後の録音自動再開: \(resumed)")
        } catch {
            logger.error("割り込み後の録音再開に失敗: \(error.localizedDescription)")
        }
    }

    private func setupLifecycleObservers() {
        let center = NotificationCenter.default
        lifecycleObservers.append(
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.updateMeterInterval(5.0) }
            }
        )
        lifecycleObservers.append(
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.updateMeterInterval(0.2) }
            }
        )
    }

    private func updateMeterInterval(_ interval: TimeInterval) {
        meterInterval = interval
        if isRecording {
            startMeteringTimer()
        }
    }

    private func startMeteringTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: meterInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.recorder, self.isRecording else { return }
                if self.meterInterval < 1.0 {
                    recorder.updateMeters()
                    let power = Double(recorder.averagePower(forChannel: 0))
                    // -60dB〜0dB を 0.0〜1.0 に正規化
                    self.currentMeterLevel = max(0.0, min(1.0, (power + 60.0) / 60.0))
                }
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
