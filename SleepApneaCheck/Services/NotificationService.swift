import Foundation
import os
import UserNotifications

/// 就寝前リマインダー通知を管理するサービス
@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var shouldOpenMonitorTab = false

    @Published var isReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isReminderEnabled, forKey: Self.enabledKey)
        }
    }

    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: Self.hourKey)
        }
    }

    @Published var reminderMinute: Int {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: Self.minuteKey)
        }
    }

    private static let enabledKey = "sleep_reminder_enabled"
    private static let hourKey = "sleep_reminder_hour"
    private static let minuteKey = "sleep_reminder_minute"
    private static let notificationIdentifier = "daily_sleep_check_reminder"

    private let logger = Logger(subsystem: "com.sleepapneacheck.app", category: "NotificationService")

    override init() {
        let defaults = UserDefaults.standard
        self.isReminderEnabled = defaults.bool(forKey: Self.enabledKey)
        let savedHour = defaults.object(forKey: Self.hourKey) as? Int
        let savedMinute = defaults.object(forKey: Self.minuteKey) as? Int
        self.reminderHour = savedHour ?? 22
        self.reminderMinute = savedMinute ?? 30
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.shouldOpenMonitorTab = true
        }
        completionHandler()
    }

    /// 通知権限を要求し、毎日のリマインダーをスケジュールする
    func updateSchedule(enabled: Bool, hour: Int, minute: Int) async -> Bool {
        reminderHour = hour
        reminderMinute = minute

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])

        guard enabled else {
            isReminderEnabled = false
            return true
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                isReminderEnabled = false
                return false
            }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.reminder.title")
            content.body = String(localized: "notification.reminder.body")
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.notificationIdentifier,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
            isReminderEnabled = true
            return true
        } catch {
            logger.error("リマインダー通知設定失敗: \(error.localizedDescription)")
            isReminderEnabled = false
            return false
        }
    }
}
