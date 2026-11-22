import SwiftUI

/// スコアを円形ゲージで表示するコンポーネント
struct ScoreGaugeView: View {
    let title: String
    let score: Int
    let maxScore: Int
    let color: Color

    private var progress: Double {
        guard maxScore > 0 else { return 0 }
        return min(1.0, max(0.0, Double(score) / Double(maxScore)))
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: progress)

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.title2.bold())
                        .monospacedDigit()
                    Text("/ \(maxScore)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, height: 84)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}
