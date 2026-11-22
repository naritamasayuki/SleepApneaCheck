import Charts
import SwiftUI

/// 過去の問診・睡眠録音履歴と推移グラフ画面
struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionService: SubscriptionService

    @State private var selectedSegment = 0
    @State private var selectedScreening: ScreeningResult?
    @State private var selectedSession: SleepAudioSession?
    @State private var showPaywall = false
    @StateObject private var previewRecorder = AudioRecorderService()

    private var visibleScreenings: [ScreeningResult] {
        if subscriptionService.isPro {
            return appState.screenings
        }
        return Array(appState.screenings.prefix(SubscriptionService.freeHistoryLimit))
    }

    private var visibleSessions: [SleepAudioSession] {
        if subscriptionService.isPro {
            return appState.audioSessions
        }
        return Array(appState.audioSessions.prefix(SubscriptionService.freeHistoryLimit))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedSegment) {
                    Text(String(localized: "history.segment.screening")).tag(0)
                    Text(String(localized: "history.segment.audio")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedSegment == 0 {
                    screeningHistoryContent
                } else {
                    audioHistoryContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "history.title"))
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            .sheet(item: $selectedScreening) { result in
                ScreeningResultView(result: result)
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session, recorderService: previewRecorder)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    @ViewBuilder
    private var screeningHistoryContent: some View {
        if appState.screenings.isEmpty {
            ContentUnavailableView(
                String(localized: "history.empty.screening.title"),
                systemImage: "checklist",
                description: Text(String(localized: "history.empty.screening.desc"))
            )
        } else {
            List {
                if appState.screenings.count >= 2 {
                    Section(String(localized: "history.chart.screening_trend")) {
                        Chart(visibleScreenings.reversed()) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("Score", item.stopBangScore)
                            )
                            PointMark(
                                x: .value("Date", item.date),
                                y: .value("Score", item.stopBangScore)
                            )
                            .foregroundStyle(item.riskLevel.themeColor)
                        }
                        .chartYScale(domain: 0...8)
                        .frame(height: 150)
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    ForEach(visibleScreenings) { item in
                        Button {
                            selectedScreening = item
                        } label: {
                            HStack {
                                Image(systemName: item.riskLevel.symbolName)
                                    .foregroundStyle(item.riskLevel.themeColor)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.riskLevel.localizedTitle)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("STOP-Bang: \(item.stopBangScore)/8")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.primary)
                                    Text("ESS: \(item.essScore)/24")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        appState.deleteScreening(at: offsets)
                    }
                }

                if !subscriptionService.isPro && appState.screenings.count > SubscriptionService.freeHistoryLimit {
                    proHistoryGateSection
                }
            }
        }
    }

    @ViewBuilder
    private var audioHistoryContent: some View {
        if appState.audioSessions.isEmpty {
            ContentUnavailableView(
                String(localized: "history.empty.audio.title"),
                systemImage: "waveform.and.mic",
                description: Text(String(localized: "history.empty.audio.desc"))
            )
        } else {
            List {
                if appState.audioSessions.count >= 2 {
                    Section(String(localized: "history.chart.audio_trend")) {
                        Chart(visibleSessions.reversed()) { session in
                            BarMark(
                                x: .value("Date", session.recordedAt),
                                y: .value("Events/h", session.estimatedEventsPerHour)
                            )
                            .foregroundStyle(session.audioRiskCategory.themeColor)
                        }
                        .frame(height: 150)
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    ForEach(visibleSessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            HStack {
                                Image(systemName: session.audioRiskCategory.symbolName)
                                    .foregroundStyle(session.audioRiskCategory.themeColor)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(
                                        String(
                                            localized: "history.audio.summary \(session.apneaPauseCount) \(Int(session.snoringPercentage))"
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f/h", session.estimatedEventsPerHour))
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(session.audioRiskCategory.themeColor)
                            }
                        }
                    }
                    .onDelete { offsets in
                        appState.deleteAudioSession(at: offsets)
                    }
                }

                if !subscriptionService.isPro && appState.audioSessions.count > SubscriptionService.freeHistoryLimit {
                    proHistoryGateSection
                }
            }
        }
    }

    private var proHistoryGateSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.yellow)
                    Text(String(localized: "history.pro_gate"))
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
        }
    }
}
