import SwiftUI

/// 5問でできる睡眠時無呼吸の簡易判定ビュー（結果内に免責事項を表示）
struct QuickCheckView: View {
    @State private var answers: [QuickCheckAnswer] = Array(
        repeating: .no,
        count: QuickCheckQuestion.allCases.count
    )
    @State private var quickResult: QuickCheckResult?

    /// 詳細問診タブへの切り替えコールバック
    var onSwitchToDetailed: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    DisclaimerBanner()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(QuickCheckQuestion.allCases) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.localizedPrompt)
                                .font(.subheadline)
                            Picker("", selection: $answers[question.rawValue]) {
                                ForEach(QuickCheckAnswer.allCases) { option in
                                    Text(option.localizedTitle).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(String(localized: "quickcheck.section.header"))
                } footer: {
                    Text(String(localized: "quickcheck.section.footer"))
                }

                Section {
                    Button {
                        withAnimation {
                            quickResult = QuickCheckCalculator.evaluate(answers: answers)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo("quickResultSection", anchor: .top)
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label(String(localized: "quickcheck.button.evaluate"), systemImage: "bolt.heart.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    if quickResult != nil {
                        Button(role: .destructive) {
                            withAnimation {
                                answers = Array(repeating: .no, count: QuickCheckQuestion.allCases.count)
                                quickResult = nil
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text(String(localized: "screening.button.reset"))
                                Spacer()
                            }
                        }
                    }
                }

                if let result = quickResult {
                    Section(String(localized: "quickcheck.result.section_title")) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: result.riskLevel.symbolName)
                                    .font(.title2)
                                    .foregroundStyle(result.riskLevel.themeColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.riskLevel.localizedTitle)
                                        .font(.headline)
                                        .foregroundStyle(result.riskLevel.themeColor)
                                    Text(String(localized: "quickcheck.result.score \(result.totalPoints) \(result.maxPoints)"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(result.summaryMessage)
                                .font(.subheadline)

                            // 簡易判定結果内の免責事項ボックス
                            VStack(alignment: .leading, spacing: 6) {
                                Label(String(localized: "quickcheck.disclaimer.title"), systemImage: "exclamationmark.shield.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                Text(String(localized: "quickcheck.disclaimer.body"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button {
                                onSwitchToDetailed()
                            } label: {
                                Label(String(localized: "quickcheck.button.to_detailed"), systemImage: "checklist")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 6)
                    }
                    .id("quickResultSection")
                }
            }
        }
    }
}
