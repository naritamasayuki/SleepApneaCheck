import Charts
import SwiftUI

/// 過去の問診・睡眠録音履歴と推移グラフ画面
struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthKitService: HealthKitService
    @EnvironmentObject private var recorderService: AudioRecorderService

    @State private var selectedSegment = 0
    @State private var selectedScreening: ScreeningResult?
    @State private var selectedSession: SleepAudioSession?
    @State private var pdfReportURL: URL?

    private var visibleScreenings: [ScreeningResult] {
        appState.screenings
    }

    private var visibleSessions: [SleepAudioSession] {
        appState.audioSessions
    }

    private var realSessionsForChart: [SleepAudioSession] {
        appState.audioSessions.filter { !$0.isSimulated }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedSegment) {
                    Text(String(localized: "history.segment.screening")).tag(0)
                    Text(String(localized: "history.segment.audio")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                healthKitSummaryBanner
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                if selectedSegment == 0 {
                    screeningHistoryContent
                } else {
                    audioHistoryContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "history.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = pdfReportURL {
                        ShareLink(item: url) {
                            Label(String(localized: "pdf.report.short_button"), systemImage: "doc.richtext")
                        }
                    }
                }
            }
            .onAppear {
                refreshPDFReport()
            }
            .onChange(of: appState.screenings.count) { _, _ in
                refreshPDFReport()
            }
            .onChange(of: appState.audioSessions.count) { _, _ in
                refreshPDFReport()
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            .sheet(item: $selectedScreening) { result in
                ScreeningResultView(result: result)
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session, recorderService: recorderService)
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
                if realSessionsForChart.count >= 2 {
                    Section(String(localized: "history.chart.audio_trend")) {
                        Chart(realSessionsForChart.reversed()) { session in
                            BarMark(
                                x: .value("Date", session.recordedAt),
                                y: .value("Score", session.snoreScore)
                            )
                            .foregroundStyle(session.audioRiskCategory.themeColor)
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 150)
                        .padding(.vertical, 8)
                    }
                }

                let tagStats = RemedyAnalyticsService.analyze(sessions: appState.audioSessions)
                if !tagStats.isEmpty {
                    Section(String(localized: "history.analytics.remedies_title")) {
                        ForEach(tagStats) { stat in
                            HStack {
                                Image(systemName: stat.tag.symbolName)
                                    .foregroundStyle(.blue)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stat.tag.localizedTitle)
                                        .font(.subheadline.bold())
                                    Text(String(localized: "history.analytics.avg_score \(Int(stat.averageScoreWithTag.rounded())) \(stat.sessionCount)"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let delta = stat.scoreDelta {
                                    let rounded = Int(delta.rounded())
                                    let sign = rounded > 0 ? "+" : ""
                                    Text("\(sign)\(rounded)")
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundStyle(rounded < 0 ? .green : (rounded > 0 ? .red : .secondary))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            (rounded < 0 ? Color.green : (rounded > 0 ? Color.red : Color.gray))
                                                .opacity(0.14)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
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

                                    if !session.tags.isEmpty {
                                        Text(session.tags.map(\.localizedTitle).joined(separator: " / "))
                                            .font(.caption2)
                                            .foregroundStyle(.blue)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(localized: "history.audio.score \(session.snoreScore)"))
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundStyle(session.audioRiskCategory.themeColor)
                                    if let rating = session.morningRating {
                                        Text(String(repeating: "★", count: rating))
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        appState.deleteAudioSession(at: offsets)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var healthKitSummaryBanner: some View {
        if healthKitService.isAvailable {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "healthkit.card.title"))
                        .font(.caption.bold())
                    if healthKitService.isAuthorized {
                        HStack(spacing: 10) {
                            if let hours = healthKitService.lastSleepDurationHours {
                                Text(String(format: "%.1fh", hours))
                                    .font(.caption.monospacedDigit())
                            }
                            if let spo2 = healthKitService.latestOxygenSaturationPercent {
                                Text(String(format: "SpO2 %.0f%%", spo2))
                                    .font(.caption.monospacedDigit())
                            }
                            if healthKitService.lastSleepDurationHours == nil && healthKitService.latestOxygenSaturationPercent == nil {
                                Text(String(localized: "healthkit.no_recent_data"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(String(localized: "healthkit.card.subtitle"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    Task {
                        await healthKitService.requestAuthorizationAndRefresh()
                    }
                } label: {
                    Text(
                        healthKitService.isAuthorized
                            ? String(localized: "healthkit.button.refresh")
                            : String(localized: "healthkit.button.connect")
                    )
                    .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func refreshPDFReport() {
        guard !appState.screenings.isEmpty || !appState.audioSessions.isEmpty else {
            pdfReportURL = nil
            return
        }
        pdfReportURL = ReportExportService.generateDoctorReportPDF(
            screenings: appState.screenings,
            audioSessions: appState.audioSessions
        )
    }
}
