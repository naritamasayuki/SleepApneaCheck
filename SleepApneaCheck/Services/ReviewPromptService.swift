import Foundation

/// App Store レビュー依頼（SKStoreReviewController / requestReview）の適切な表示タイミングを判定するサービス
enum ReviewPromptService {
    private static let completedCountKey = "review_completed_action_count"
    private static let lastPromptDateKey = "review_last_prompt_date"

    /// レビュー依頼を行う節目回数
    static let triggerMilestones: Set<Int> = [3, 10, 25]
    /// 連続表示を避けるための最小クールダウン期間（30日）
    static let minimumCooldownSeconds: TimeInterval = 30 * 24 * 3600

    /// 完了アクションを記録し、レビュー依頼を表示すべきかどうかを返す
    @discardableResult
    static func recordActionAndShouldPrompt(
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        let newCount = defaults.integer(forKey: completedCountKey) + 1
        defaults.set(newCount, forKey: completedCountKey)

        guard triggerMilestones.contains(newCount) else {
            return false
        }

        if let lastDate = defaults.object(forKey: lastPromptDateKey) as? Date,
           now.timeIntervalSince(lastDate) < minimumCooldownSeconds {
            return false
        }

        defaults.set(now, forKey: lastPromptDateKey)
        return true
    }
}
