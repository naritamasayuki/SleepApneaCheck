import SwiftUI

/// アプリ設定・リマインダー・Proプラン管理画面
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var notificationService: NotificationService

    @State private var showPaywall = false
    @State private var showClearConfirm = false
    @State private var notificationDeniedAlert = false
    @State private var reminderTime: Date = Date()
    @State private var hasLoadedInitialTime = false
    @State private var legalDocument: LegalDocumentType?

    var body: some View {
        NavigationStack {
            Form {
                // プレミアムプランセクション
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: subscriptionService.isPro ? "crown.fill" : "crown")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    subscriptionService.isPro
                                        ? String(localized: "settings.pro.active_title")
                                        : String(localized: "settings.pro.upgrade_title")
                                )
                                .font(.headline)
                                .foregroundStyle(.primary)

                                Text(
                                    subscriptionService.isPro
                                        ? String(localized: "settings.pro.active_desc")
                                        : String(localized: "settings.pro.upgrade_desc")
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

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

                    HStack {
                        Text(String(localized: "settings.version"))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                #if DEBUG
                Section("Developer") {
                    Toggle("Debug Pro Mode", isOn: Binding(
                        get: { subscriptionService.isPro },
                        set: { _ in subscriptionService.toggleDebugPro() }
                    ))
                }
                #endif
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(item: $legalDocument) { doc in
                LegalDocumentView(documentType: doc)
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
