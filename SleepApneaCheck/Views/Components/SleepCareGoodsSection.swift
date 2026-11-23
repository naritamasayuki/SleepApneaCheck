import SwiftUI

/// 睡眠時無呼吸・いびき対策グッズの Amazon アソシエイトリンク一覧セクション（PR表記付き）
struct SleepCareGoodsSection: View {
    @Environment(\.openURL) private var openURL
    var compact: Bool = false

    private var displayedGoods: [SleepCareGood] {
        compact ? Array(SleepCareGood.allCases.prefix(3)) : SleepCareGood.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "goods.section.title"))
                    .font(.headline)
                Spacer()
                Text("PR")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.18))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                    .accessibilityLabel("PR")
            }

            Text(String(localized: "goods.section.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(displayedGoods) { good in
                    Button {
                        if let url = AmazonAffiliateService.searchURL(for: good) {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: good.symbolName)
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .frame(width: 32, height: 32)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(good.localizedTitle)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Text(good.localizedDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(localized: "goods.button.amazon"))
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(String(localized: "goods.section.pr_disclaimer"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
