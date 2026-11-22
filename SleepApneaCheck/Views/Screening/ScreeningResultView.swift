import SwiftUI

/// 問診スクリーニング結果の表示画面
struct ScreeningResultView: View {
    @Environment(\.dismiss) private var dismiss
    let result: ScreeningResult

    private var shareSummaryText: String {
        let dateStr = result.date.formatted(date: .abbreviated, time: .shortened)
        return String(
            localized: "screening.share.template \(dateStr) \(result.riskLevel.localizedTitle) \(result.stopBangScore) \(result.essScore) \(result.sleepinessLevel.localizedTitle)"
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 総合リスクカード
                    VStack(spacing: 12) {
                        Image(systemName: result.riskLevel.symbolName)
                            .font(.system(size: 48))
                            .foregroundStyle(result.riskLevel.themeColor)

                        Text(result.riskLevel.localizedTitle)
                            .font(.title2.bold())
                            .foregroundStyle(result.riskLevel.themeColor)

                        Text(result.date.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(result.riskLevel.themeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // スコアゲージ
                    HStack(spacing: 32) {
                        ScoreGaugeView(
                            title: String(localized: "screening.result.stopbang"),
                            score: result.stopBangScore,
                            maxScore: 8,
                            color: result.riskLevel.themeColor
                        )
                        ScoreGaugeView(
                            title: String(localized: "screening.result.ess"),
                            score: result.essScore,
                            maxScore: 24,
                            color: result.essScore >= 11 ? .orange : .blue
                        )
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // アドバイス
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "screening.result.advice_header"))
                            .font(.headline)

                        Text(result.riskLevel.localizedAdvice)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Divider()

                        HStack {
                            Text(String(localized: "screening.result.sleepiness_label"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(result.sleepinessLevel.localizedTitle)
                                .font(.subheadline.bold())
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 医師・家族への共有
                    ShareLink(item: shareSummaryText) {
                        Label(String(localized: "screening.result.share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    DisclaimerBanner()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "screening.result.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
