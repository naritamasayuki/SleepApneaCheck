import SwiftUI

/// 医療機器ではない旨の免責事項バナー
struct DisclaimerBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)

            Text(String(localized: "disclaimer.banner"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension ApneaRiskLevel {
    /// リスクレベルに応じた表示色
    var themeColor: Color {
        switch self {
        case .low: return .green
        case .intermediate: return .orange
        case .high: return .red
        }
    }

    /// リスクレベルに応じたSF Symbolsアイコン名
    var symbolName: String {
        switch self {
        case .low: return "checkmark.shield.fill"
        case .intermediate: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon.fill"
        }
    }
}
