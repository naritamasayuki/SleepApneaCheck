import Charts
import SwiftUI

/// 睡眠録音解析セッションの詳細画面
struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let session: SleepAudioSession
    @ObservedObject var recorderService: AudioRecorderService

    @State private var playbackError: String?

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

                    // サマリーカード
                    VStack(spacing: 12) {
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
                                value: String(format: "%.0fs", session.longestPauseSeconds)
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

                    // 録音再生ボタン
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
                    }

                    // 検出イベントリスト
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "session.events.title"))
                            .font(.headline)

                        if session.events.isEmpty {
                            Text(String(localized: "session.events.empty"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(session.events) { event in
                                HStack {
                                    Image(systemName: event.type == .apneaPause ? "pause.circle.fill" : "waveform")
                                        .foregroundStyle(event.type == .apneaPause ? .red : .orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.type.localizedTitle)
                                            .font(.subheadline.bold())
                                        Text(formatOffset(event.startOffsetSeconds))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(String(format: "%.0fs", event.durationSeconds))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                Divider()
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

                    DisclaimerBanner()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "session.detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        recorderService.stopPlayback()
                        dismiss()
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

    private func formatOffset(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
