import SwiftUI

/// アプリ設定・リマインダー・サポート画面
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var adService: AdService

    @State private var showClearConfirm = false
    @State private var notificationDeniedAlert = false
    @State private var reminderTime: Date = Date()
    @State private var hasLoadedInitialTime = false
    @State private var legalDocument: LegalDocumentType?
    @State private var showFeedbackForm = false

    var body: some View {
        NavigationStack {
            Form {
                // 音声解析感度
                Section {
                    Picker(String(localized: "settings.sensitivity.title"), selection: $appState.sensitivity) {
                        ForEach(AudioSensitivity.allCases) { level in
                            Text(level.localizedTitle).tag(level)
                        }
                    }
                } header: {
                    Text(String(localized: "settings.section.audio"))
                } footer: {
                    Text(String(localized: "settings.sensitivity.footer"))
                }

                // 就寝前リマインダー通知
                Section {
                    Toggle(
                        String(localized: "settings.reminder.toggle"),
                        isOn: Binding(
                            get: { notificationService.isReminderEnabled },
                            set: { newValue in
                                Task {
                                    await applyReminder(enabled: newValue)
                                }
                            }
                        )
                    )

                    if notificationService.isReminderEnabled {
                        DatePicker(
                            String(localized: "settings.reminder.time"),
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderTime) { _, _ in
                            guard hasLoadedInitialTime else { return }
                            Task {
                                await applyReminder(enabled: true)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "settings.section.notification"))
                }

                // ユーザーフィードバック・バグ報告
                Section {
                    Button {
                        showFeedbackForm = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "settings.feedback.title"))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(String(localized: "settings.feedback.subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "settings.section.support"))
                }

                // データ管理
                Section(String(localized: "settings.section.data")) {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Text(String(localized: "settings.data.clear_all"))
                    }
                }

                // 免責事項・アプリ情報
                Section(String(localized: "settings.section.about")) {
                    DisclaimerBanner()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)

                    Button(String(localized: "legal.privacy_policy.title")) {
                        legalDocument = .privacyPolicy
                    }

                    Button(String(localized: "legal.terms.title")) {
                        legalDocument = .termsOfUse
                    }

                    if adService.isPrivacyOptionsRequired {
                        Button(String(localized: "settings.privacy_options")) {
                            Task { await adService.presentPrivacyOptions() }
                        }
                    }

                    HStack {
                        Text(String(localized: "settings.version"))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .onAppear {
                var components = DateComponents()
                components.hour = notificationService.reminderHour
                components.minute = notificationService.reminderMinute
                if let date = Calendar.current.date(from: components) {
                    reminderTime = date
                }
                DispatchQueue.main.async {
                    hasLoadedInitialTime = true
                }
            }
            .sheet(item: $legalDocument) { doc in
                LegalDocumentView(documentType: doc)
            }
            .sheet(isPresented: $showFeedbackForm) {
                FeedbackView()
            }
            .confirmationDialog(
                String(localized: "settings.data.clear_confirm_title"),
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.data.clear_confirm_button"), role: .destructive) {
                    appState.clearAllHistory()
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            }
            .alert(String(localized: "common.error"), isPresented: $notificationDeniedAlert) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(String(localized: "settings.reminder.permission_denied"))
            }
        }
    }

    private func applyReminder(enabled: Bool) async {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = comps.hour ?? 22
        let minute = comps.minute ?? 30
        let success = await notificationService.updateSchedule(enabled: enabled, hour: hour, minute: minute)
        if enabled && !success {
            notificationDeniedAlert = true
        }
    }
}
