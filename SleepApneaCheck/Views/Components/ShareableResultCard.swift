import SwiftUI
import UIKit

/// LINE や家族への共有用にレンダリングする問診結果カードビュー
struct ShareableResultCard: View {
    let result: ScreeningResult

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(String(localized: "screening.title"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(result.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.16, blue: 0.36), Color(red: 0.14, green: 0.34, blue: 0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            VStack(spacing: 10) {
                Image(systemName: result.riskLevel.symbolName)
                    .font(.system(size: 42))
                    .foregroundStyle(result.riskLevel.themeColor)

                Text(result.riskLevel.localizedTitle)
                    .font(.title2.bold())
                    .foregroundStyle(result.riskLevel.themeColor)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("STOP-Bang")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(result.stopBangScore) / 8")
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    Divider().frame(height: 36)
                    VStack(spacing: 4) {
                        Text("ESS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(result.essScore) / 24")
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 6)

                Text(result.riskLevel.localizedAdvice)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(String(localized: "disclaimer.banner"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 360)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    /// SwiftUI ビューを共有用 Image へレンダリングする
    @MainActor
    static func renderImage(for result: ScreeningResult) -> Image? {
        let renderer = ImageRenderer(content: ShareableResultCard(result: result))
        renderer.scale = 3.0
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
