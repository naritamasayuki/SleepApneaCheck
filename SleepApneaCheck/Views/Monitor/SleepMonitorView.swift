import StoreKit
import SwiftUI
import UIKit

/// 睡眠音声の録音・簡易解析画面
struct SleepMonitorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.requestReview) private var requestReview

    @StateObject private var recorderService = AudioRecorderService()
    @State private var isAnalyzing = false
    @State private var selectedSession: SleepAudioSession?
    @State private var selectedTags: [SleepCareTag] = []
    @State private var recorderErrorMessage: String?
    @State private var showPermissionSettingsAlert = false

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

                        Text(formattedDuration(recorderService.elapsedSeconds))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        // 音量レベルメーター
                        ProgressView(value: recorderService.currentMeterLevel)
                            .tint(recorderService.isRecording ? .red : .blue)
                            .padding(.horizontal, 32)

                        Label(String(localized: "monitor.bedside_tip"), systemImage: "battery.100.bolt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        if isAnalyzing {
                            ProgressView(String(localized: "monitor.analyzing"))
                                .padding(.top, 4)
                        } else {
                            Button {
                                Task {
                                    await toggleRecording()
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

    private func toggleRecording() async {
        if recorderService.isRecording {
            if let fileURL = recorderService.stopRecording() {
                await analyzeRecording(at: fileURL)
            }
            return
        }

        do {
            let dirURL = try appState.repository.ensureAudioDirectoryURL()
            try await recorderService.startRecording(
                in: dirURL,
                maxDurationSeconds: nil
            ) { autoStoppedURL in
                Task { @MainActor in
                    await analyzeRecording(at: autoStoppedURL)
                }
            }
        } catch AudioRecorderError.permissionDenied {
            showPermissionSettingsAlert = true
        } catch {
            recorderErrorMessage = error.localizedDescription
        }
    }

    private func analyzeRecording(at url: URL) async {
        isAnalyzing = true
        let sensitivity = appState.sensitivity
        let tagsToAttach = selectedTags
        defer { isAnalyzing = false }

        do {
            var session = try await Task.detached(priority: .userInitiated) {
                try AudioAnalyzer.analyzeFile(at: url, sensitivity: sensitivity)
            }.value
            session.tags = tagsToAttach
            appState.addAudioSession(session)
            selectedSession = session
            if ReviewPromptService.recordActionAndShouldPrompt() {
                requestReview()
            }
        } catch {
            recorderErrorMessage = error.localizedDescription
        }
    }

    private func runSimulatedAnalysis() {
        var session = AudioAnalyzer.generateSimulatedSession(sensitivity: appState.sensitivity)
        session.tags = selectedTags
        appState.addAudioSession(session)
        selectedSession = session
        if ReviewPromptService.recordActionAndShouldPrompt() {
            requestReview()
        }
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
