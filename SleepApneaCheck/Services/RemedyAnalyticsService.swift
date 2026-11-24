import Foundation

/// 対策グッズ・生活習慣タグごとの効果比較サマリー
struct TagEffectivenessSummary: Identifiable, Equatable, Sendable {
    var id: String { tag.id }
    let tag: SleepCareTag
    let sessionCount: Int
    /// タグありセッションの平均いびきスコア
    let averageScoreWithTag: Double
    /// タグなしセッションの平均いびきスコア（比較対象がない場合は nil）
    let averageScoreWithoutTag: Double?

    /// 変化量（マイナスならいびきスコア改善、プラスなら悪化）
    var scoreDelta: Double? {
        guard let baseline = averageScoreWithoutTag else { return nil }
        return averageScoreWithTag - baseline
    }
}

/// 過去の睡眠録音履歴から「どの対策が効いているか／何が悪化要因か」を分析するサービス
enum RemedyAnalyticsService {
    /// タグ別の平均いびきスコアおよびタグなし時との差分を算出する
    static func analyze(sessions: [SleepAudioSession]) -> [TagEffectivenessSummary] {
        guard !sessions.isEmpty else { return [] }

        var results: [TagEffectivenessSummary] = []
        for tag in SleepCareTag.allCases {
            let withTag = sessions.filter { $0.tags.contains(tag) }
            guard !withTag.isEmpty else { continue }

            let withoutTag = sessions.filter { !$0.tags.contains(tag) }
            let avgWith = Double(withTag.map(\.snoreScore).reduce(0, +)) / Double(withTag.count)
            let avgWithout: Double? = withoutTag.isEmpty
                ? nil
                : Double(withoutTag.map(\.snoreScore).reduce(0, +)) / Double(withoutTag.count)

            results.append(
                TagEffectivenessSummary(
                    tag: tag,
                    sessionCount: withTag.count,
                    averageScoreWithTag: avgWith,
                    averageScoreWithoutTag: avgWithout
                )
            )
        }

        // 改善幅が大きい順（deltaが小さい順）、比較対象がないものは末尾
        return results.sorted { lhs, rhs in
            switch (lhs.scoreDelta, rhs.scoreDelta) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.sessionCount > rhs.sessionCount
            }
        }
    }
}
