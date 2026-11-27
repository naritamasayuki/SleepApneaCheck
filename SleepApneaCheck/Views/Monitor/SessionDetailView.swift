import Charts
import SwiftUI

/// 睡眠録音解析セッションの詳細画面
struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let session: SleepAudioSession
    @ObservedObject var recorderService: AudioRecorderService

    @State private var playbackError: String?
    @State private var editableTags: [SleepCareTag] = []
    @State private var morningRating: Int?
    @State private var noteText: String = ""
    @FocusState private var isNoteFocused: Bool

    private var audioURL: URL? {
        guard let fileName = session.audioFileName else { return nil }
        return appState.repository.audioFileURL(for: fileName)
    }

    private var shareSummaryText: String {
        let dateStr = session.recordedAt.formatted(date: .abbreviated, time: .shortened)
        return String(
            localized: "session.share.template \(dateStr) \(session.audioRiskCategory.localizedTitle) \(session.apneaPauseCount) \(Int(session.snoringPercentage))"
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if session.isSimulated {
                        Label(String(localized: "session.simulated_badge"), systemImage: "sparkles")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }

                    // サマリーカード（いびきスコアゲージ＋主要指標）
                    VStack(spacing: 14) {
                        HStack(spacing: 16) {
                            ScoreGaugeView(
                                title: String(localized: "session.metric.snore_score"),
                                score: session.snoreScore,
                                maxScore: 100,
                                color: session.audioRiskCategory.themeColor
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: session.audioRiskCategory.symbolName)
                                        .foregroundStyle(session.audioRiskCategory.themeColor)
                                    Text(session.audioRiskCategory.localizedTitle)
                                        .font(.headline)
                                        .foregroundStyle(session.audioRiskCategory.themeColor)
                                }
                                Text(session.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            metricBox(
                                title: String(localized: "session.metric.events_per_hour"),
                                value: String(format: "%.1f", session.estimatedEventsPerHour)
                            )
                            metricBox(
                                title: String(localized: "session.metric.apnea_pauses"),
                                value: "\(session.apneaPauseCount)"
                            )
                            metricBox(
                                title: String(localized: "session.metric.snoring_ratio"),
                                value: String(format: "%.0f%%", session.snoringPercentage)
                            )
                            metricBox(
                                title: String(localized: "session.metric.longest_pause"),
                                value: Duration.seconds(Int(session.longestPauseSeconds))
                                    .formatted(.units(allowed: [.seconds], width: .narrow))
                            )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 音量タイムライングラフ
                    if !session.normalizedLevels.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: "session.timeline.title"))
                                .font(.headline)

                            Chart(Array(session.normalizedLevels.enumerated()), id: \.offset) { index, level in
                                BarMark(
                                    x: .value("Segment", index),
                                    y: .value("Level", level)
                                )
                                .foregroundStyle(level > 0.55 ? Color.orange : Color.blue.opacity(0.7))
                            }
                            .chartYScale(domain: 0...1)
                            .chartXAxis(.hidden)
                            .frame(height: 140)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // 録音再生ボタン（進行中の録音がある場合は誤停止防止のため無効化）
                    if let url = audioURL, FileManager.default.fileExists(atPath: url.path) {
                        Button {
                            do {
                                try recorderService.togglePlayback(url: url)
                            } catch {
                                playbackError = error.localizedDescription
                            }
                        } label: {
                            Label(
                                recorderService.isPlaying
                                    ? String(localized: "session.button.stop_playback")
                                    : String(localized: "session.button.play"),
                                systemImage: recorderService.isPlaying ? "stop.circle.fill" : "play.circle.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(recorderService.isRecording)
                    }

                    // 対策・状況タグ（後から編集可能）
                    SleepCareTagPicker(selectedTags: $editableTags)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .onChange(of: editableTags) { _, newValue in
                            appState.updateAudioSessionTags(sessionID: session.id, tags: newValue)
                        }

                    // 起床時の熟睡感（★1〜5）＆ひとことメモ
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "session.journal.title"))
                            .font(.subheadline.bold())

                        HStack(spacing: 10) {
                            Text(String(localized: "session.journal.rating_label"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    morningRating = (morningRating == star) ? nil : star
                                    appState.updateAudioSessionJournal(
                                        sessionID: session.id,
                                        morningRating: morningRating,
                                        note: noteText
                                    )
                                } label: {
                                    Image(systemName: (morningRating ?? 0) >= star ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundStyle((morningRating ?? 0) >= star ? .yellow : .gray.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(star) / 5")
                            }
                        }

                        TextField(String(localized: "session.journal.note_placeholder"), text: $noteText)
                            .textFieldStyle(.roundedBorder)
                            .focused($isNoteFocused)
                            .onChange(of: isNoteFocused) { _, focused in
                                if !focused {
                                    saveJournalIfNeeded()
                                }
                            }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 検出イベントリスト（録音ファイルがある場合はタップで5秒前からピンポイント再生）
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(String(localized: "session.events.title"))
                                .font(.headline)
                            Spacer()
                            if let url = audioURL, FileManager.default.fileExists(atPath: url.path) {
                                Text(String(localized: "session.events.tap_to_play"))
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }

                        if session.events.isEmpty {
                            Text(String(localized: "session.events.empty"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            let hasAudioFile = audioURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                            LazyVStack(spacing: 4) {
                                ForEach(session.events) { event in
                                    let isThisEventPlaying = recorderService.isPlaying && recorderService.activeEventID == event.id
                                    Button {
                                        guard hasAudioFile, let url = audioURL else { return }
                                        do {
                                            let seekStart = max(0, event.startOffsetSeconds - 5.0)
                                            try recorderService.play(url: url, startingAt: seekStart, eventID: event.id)
                                        } catch {
                                            playbackError = error.localizedDescription
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: event.type == .apneaPause ? "pause.circle.fill" : "waveform")
                                                .foregroundStyle(event.type == .apneaPause ? .red : .orange)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(event.type.localizedTitle)
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.primary)
                                                Text(formatEventTime(event.startOffsetSeconds))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(Duration.seconds(Int(event.durationSeconds))
                                                .formatted(.units(allowed: [.seconds], width: .narrow)))
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                            if hasAudioFile {
                                                Image(systemName: isThisEventPlaying ? "stop.circle.fill" : "play.circle")
                                                    .foregroundStyle(isThisEventPlaying ? .red : .blue)
                                                    .font(.title3)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!hasAudioFile || recorderService.isRecording)
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    ShareLink(item: shareSummaryText) {
                        Label(String(localized: "screening.result.share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if session.audioRiskCategory != .high {
                        SleepCareGoodsSection()
                    }

                    DisclaimerBanner()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "session.detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                editableTags = session.tags
                morningRating = session.morningRating
                noteText = session.note
            }
            .onDisappear {
                saveJournalIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        recorderService.stopPlayback()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "common.done")) {
                        isNoteFocused = false
                    }
                }
            }
            .alert(
                String(localized: "common.error"),
                isPresented: Binding(
                    get: { playbackError != nil },
                    set: { if !$0 { playbackError = nil } }
                )
            ) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(playbackError ?? "")
            }
        }
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func saveJournalIfNeeded() {
        guard !session.isSimulated else { return }
        appState.updateAudioSessionJournal(
            sessionID: session.id,
            morningRating: morningRating,
            note: noteText
        )
    }

    private func formatEventTime(_ seconds: TimeInterval) -> String {
        // それ以前の割り込みで録音できなかった時間を加算して実時刻へ補正
        let missing = session.recordingGaps
            .filter { $0.fileOffsetSeconds <= seconds }
            .reduce(0) { $0 + $1.durationSeconds }
        let actualTime = session.recordedAt.addingTimeInterval(seconds + missing)
        return actualTime.formatted(date: .omitted, time: .shortened)
    }
}
