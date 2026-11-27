import StoreKit
import SwiftUI
import UIKit

/// 睡眠音声の録音・簡易解析画面
struct SleepMonitorView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var recorderService: AudioRecorderService
    @Environment(\.requestReview) private var requestReview

    @State private var isAnalyzing = false
    @State private var selectedSession: SleepAudioSession?
    @State private var selectedTags: [SleepCareTag] = []
    @State private var delayMinutes: Int = 0
    @State private var recorderErrorMessage: String?
    @State private var showPermissionSettingsAlert = false

    private let delayOptions = [0, 10, 20, 30]

    private var isCountingDownDelay: Bool {
        recorderService.remainingDelaySeconds > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DisclaimerBanner()

                    // 録音ステータスカード
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(recorderService.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.12))
                                .frame(width: 140, height: 140)
                                .scaleEffect(recorderService.isRecording ? 1.0 + recorderService.currentMeterLevel * 0.2 : 1.0)
                                .animation(.easeOut(duration: 0.15), value: recorderService.currentMeterLevel)

                            Image(systemName: recorderService.isRecording ? "waveform" : "mic.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(recorderService.isRecording ? .red : .blue)
                        }

                        if isCountingDownDelay {
                            VStack(spacing: 8) {
                                Text(String(localized: "monitor.delay.counting_down"))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                                Text(formattedDuration(TimeInterval(recorderService.remainingDelaySeconds)))
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(.orange)
                                    .monospacedDigit()
                            }
                        } else {
                            let effectiveElapsed = max(0, recorderService.elapsedSeconds - recorderService.configuredDelaySeconds)
                            Text(formattedDuration(effectiveElapsed))
                                .font(.largeTitle.weight(.bold))
                                .monospacedDigit()
                        }

                        // 音量レベルメーター
                        ProgressView(value: recorderService.currentMeterLevel)
                            .tint(recorderService.isRecording ? .red : .blue)
                            .padding(.horizontal, 32)

                        // 録音開始ディレイ設定（入眠待ちタイマー）
                        if !recorderService.isRecording && !isCountingDownDelay && !isAnalyzing {
                            VStack(spacing: 6) {
                                Text(String(localized: "monitor.delay.title"))
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $delayMinutes) {
                                    ForEach(delayOptions, id: \.self) { mins in
                                        Text(
                                            mins == 0
                                                ? String(localized: "monitor.delay.none")
                                                : String(localized: "monitor.delay.minutes \(mins)")
                                        ).tag(mins)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.horizontal, 8)
                        }

                        Label(String(localized: "monitor.bedside_tip"), systemImage: "battery.100.bolt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        if isAnalyzing {
                            ProgressView(String(localized: "monitor.analyzing"))
                                .padding(.top, 4)
                        } else if isCountingDownDelay {
                            HStack(spacing: 12) {
                                Button(role: .destructive) {
                                    recorderService.cancelRecordingAndDiscard()
                                } label: {
                                    Text(String(localized: "common.cancel"))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    recorderService.skipRemainingDelay()
                                } label: {
                                    Text(String(localized: "monitor.delay.start_now"))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            Button {
                                Task {
                                    await handleStartOrStopTap()
                                }
                            } label: {
                                Label(
                                    recorderService.isRecording
                                        ? String(localized: "monitor.button.stop")
                                        : String(localized: "monitor.button.start"),
                                    systemImage: recorderService.isRecording ? "stop.fill" : "record.circle"
                                )
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(recorderService.isRecording ? .red : .blue)
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // 就寝時の対策・状況タグ選択
                    SleepCareTagPicker(selectedTags: $selectedTags)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // デモ・シミュレーション解析（実機マイクが使えない環境でも動作確認可能）
                    if !recorderService.isRecording && !isAnalyzing {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: "monitor.demo.title"))
                                .font(.headline)
                            Text(String(localized: "monitor.demo.description"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                runSimulatedAnalysis()
                            } label: {
                                Label(String(localized: "monitor.demo.button"), systemImage: "waveform.path.ecg")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "monitor.title"))
            .safeAreaInset(edge: .bottom) {
                if !recorderService.isRecording {
                    AdBannerView()
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session, recorderService: recorderService)
            }
            .alert(
                String(localized: "common.error"),
                isPresented: Binding(
                    get: { recorderErrorMessage != nil },
                    set: { if !$0 { recorderErrorMessage = nil } }
                )
            ) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(recorderErrorMessage ?? "")
            }
            .alert(String(localized: "monitor.permission.alert_title"), isPresented: $showPermissionSettingsAlert) {
                Button(String(localized: "monitor.permission.open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "error.mic.permission_denied"))
            }
        }
    }

    private func handleStartOrStopTap() async {
        if recorderService.isRecording {
            let startedAt = recorderService.recordingStartedAt ?? Date()
            let ignoreDelay = recorderService.configuredDelaySeconds
            let interruptions = recorderService.interruptionCount
            if let fileURL = recorderService.stopRecording() {
                await analyzeRecording(
                    at: fileURL,
                    startedAt: startedAt,
                    ignoreInitialSeconds: ignoreDelay,
                    interruptionCount: interruptions
                )
            }
            return
        }

        // 入眠待ちディレイ選択時も即座に録音セッションを開始してロック中バックグラウンドを維持し、
        // 解析時に先頭のディレイ分を除外する
        await startRecordingNow(delaySeconds: TimeInterval(delayMinutes * 60))
    }

    private func startRecordingNow(delaySeconds: TimeInterval) async {
        do {
            let dirURL = try appState.repository.ensureAudioDirectoryURL()
            try await recorderService.startRecording(
                in: dirURL,
                delaySeconds: delaySeconds,
                maxDurationSeconds: nil
            ) { autoStoppedURL in
                Task { @MainActor in
                    await analyzeRecording(
                        at: autoStoppedURL,
                        startedAt: recorderService.recordingStartedAt ?? Date(),
                        ignoreInitialSeconds: recorderService.configuredDelaySeconds,
                        interruptionCount: recorderService.interruptionCount
                    )
                }
            }
        } catch AudioRecorderError.permissionDenied {
            showPermissionSettingsAlert = true
        } catch {
            recorderErrorMessage = error.localizedDescription
        }
    }

    private func analyzeRecording(
        at url: URL,
        startedAt: Date,
        ignoreInitialSeconds: TimeInterval,
        interruptionCount: Int
    ) async {
        isAnalyzing = true
        let sensitivity = appState.sensitivity
        let tagsToAttach = selectedTags
        defer { isAnalyzing = false }

        do {
            var session = try await Task.detached(priority: .userInitiated) {
                try AudioAnalyzer.analyzeFile(
                    at: url,
                    sensitivity: sensitivity,
                    recordedAt: startedAt,
                    ignoreInitialSeconds: ignoreInitialSeconds,
                    interruptionCount: interruptionCount
                )
            }.value
            session.tags = tagsToAttach
            appState.addAudioSession(session)
            selectedSession = session
            // 高リスク判定直後の不安なタイミングではレビュー依頼を出さない
            if session.audioRiskCategory != .high && ReviewPromptService.recordActionAndShouldPrompt() {
                requestReview()
            }
        } catch {
            recorderErrorMessage = error.localizedDescription
        }
    }

    private func runSimulatedAnalysis() {
        // デモ結果は本物の履歴・PDF・効果分析に混ぜずプレビューのみ表示する
        var session = AudioAnalyzer.generateSimulatedSession(sensitivity: appState.sensitivity)
        session.tags = selectedTags
        selectedSession = session
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }
}
