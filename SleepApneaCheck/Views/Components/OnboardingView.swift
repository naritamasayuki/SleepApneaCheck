import SwiftUI

/// 初回起動時にアプリの中心価値（夜間録音・準備チェックリスト・医療免責）を案内するオンボーディングビュー
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    var onStartMonitor: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    onboardingPage(
                        symbol: "waveform.and.mic",
                        color: .blue,
                        title: String(localized: "onboarding.page1.title"),
                        body: String(localized: "onboarding.page1.body")
                    )
                    .tag(0)

                    onboardingPage(
                        symbol: "bed.double.fill",
                        color: .teal,
                        title: String(localized: "onboarding.page2.title"),
                        body: String(localized: "onboarding.page2.body")
                    )
                    .tag(1)

                    onboardingPage(
                        symbol: "doc.richtext",
                        color: .indigo,
                        title: String(localized: "onboarding.page3.title"),
                        body: String(localized: "onboarding.page3.body")
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 12) {
                    if currentPage < 2 {
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            Text(String(localized: "onboarding.button.next"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            dismiss()
                            onStartMonitor()
                        } label: {
                            Label(String(localized: "onboarding.button.start_monitor"), systemImage: "record.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(String(localized: "onboarding.button.skip"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func onboardingPage(symbol: String, color: Color, title: String, body: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 130, height: 130)
                Image(systemName: symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(color)
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
