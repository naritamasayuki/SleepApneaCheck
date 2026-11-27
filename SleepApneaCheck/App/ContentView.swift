import SwiftUI

/// メインの4タブ構成ビュー
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notificationService: NotificationService
    @AppStorage("has_seen_onboarding") private var hasSeenOnboarding = false
    @State private var selectedTab = 0
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ScreeningView(onStartSleepMonitor: {
                selectedTab = 1
            })
            .tabItem {
                Label(String(localized: "tab.screening"), systemImage: "checklist")
            }
            .tag(0)

            SleepMonitorView()
                .tabItem {
                    Label(String(localized: "tab.monitor"), systemImage: "waveform.and.mic")
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label(String(localized: "tab.history"), systemImage: "chart.xyaxis.line")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gearshape")
                }
                .tag(3)
        }
        .onAppear {
            if !hasSeenOnboarding {
                showOnboarding = true
                hasSeenOnboarding = true
            }
        }
        .onChange(of: notificationService.shouldOpenMonitorTab) { _, shouldOpen in
            if shouldOpen {
                selectedTab = 1
                notificationService.shouldOpenMonitorTab = false
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                selectedTab = 1
            }
        }
        .alert(
            String(localized: "common.error"),
            isPresented: Binding(
                get: { appState.alertErrorMessage != nil },
                set: { if !$0 { appState.alertErrorMessage = nil } }
            )
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(appState.alertErrorMessage ?? "")
        }
    }
}
