import SwiftUI

/// メインの4タブ構成ビュー
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScreeningView()
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
