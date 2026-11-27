import Foundation
import UIKit

/// ユーザーフィードバックの種別
enum FeedbackCategory: String, CaseIterable, Identifiable, Sendable {
    case featureRequest
    case bugReport
    case general

    var id: String { rawValue }

    /// ローカライズされたカテゴリ表示名
    var localizedTitle: String {
        switch self {
        case .featureRequest:
            return String(localized: "feedback.category.feature")
        case .bugReport:
            return String(localized: "feedback.category.bug")
        case .general:
            return String(localized: "feedback.category.general")
        }
    }

    /// GitHub Issue 用のラベル名
    var githubLabel: String {
        switch self {
        case .featureRequest: return "enhancement"
        case .bugReport: return "bug"
        case .general: return "feedback"
        }
    }

    /// 件名プレフィックス
    var subjectPrefix: String {
        switch self {
        case .featureRequest: return "[Feature]"
        case .bugReport: return "[Bug]"
        case .general: return "[Feedback]"
        }
    }
}

/// フィードバック送信用の本文・URLを組み立てる純粋ロジック
enum FeedbackBuilder {
    static let githubIssuesBaseURL = "https://github.com/naritamasayuki/SleepApneaCheck/issues/new"
    static let supportEmail = "doronko.narunaru@gmail.com"

    /// 送信用の件名を生成する
    static func makeSubject(category: FeedbackCategory, customSubject: String) -> String {
        let trimmed = customSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "\(category.subjectPrefix) SleepApnea Check \(category.localizedTitle)"
        }
        return "\(category.subjectPrefix) \(trimmed)"
    }

    /// 送信用本文を生成する（必要に応じて端末・アプリ環境情報を添付）
    static func makeBody(
        category: FeedbackCategory,
        message: String,
        includeDeviceInfo: Bool,
        appVersion: String,
        buildNumber: String,
        osVersion: String,
        localeIdentifier: String
    ) -> String {
        var lines: [String] = []
        lines.append("Category: \(category.localizedTitle)")
        lines.append("")
        lines.append(message.trimmingCharacters(in: .whitespacesAndNewlines))

        if includeDeviceInfo {
            lines.append("")
            lines.append("---")
            lines.append("App Version: \(appVersion) (\(buildNumber))")
            lines.append("OS: iOS \(osVersion)")
            lines.append("Locale: \(localeIdentifier)")
        }

        return lines.joined(separator: "\n")
    }

    /// GitHub Issue 新規作成用のプリフィル済み URL を生成する
    static func makeGitHubIssueURL(
        category: FeedbackCategory,
        subject: String,
        body: String
    ) -> URL? {
        var components = URLComponents(string: githubIssuesBaseURL)
        components?.queryItems = [
            URLQueryItem(name: "title", value: subject),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: category.githubLabel)
        ]
        return components?.url
    }

    /// メールアプリ起動用の mailto URL を生成する
    static func makeMailtoURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }

    /// 現在の端末・アプリ情報から本文を生成する便利メソッド
    @MainActor
    static func makeCurrentBody(
        category: FeedbackCategory,
        message: String,
        includeDeviceInfo: Bool
    ) -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let osVersion = UIDevice.current.systemVersion
        let localeID = Locale.current.identifier

        return makeBody(
            category: category,
            message: message,
            includeDeviceInfo: includeDeviceInfo,
            appVersion: version,
            buildNumber: build,
            osVersion: osVersion,
            localeIdentifier: localeID
        )
    }
}
