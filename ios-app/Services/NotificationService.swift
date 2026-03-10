import UserNotifications
import UIKit

/// Manages local and push notifications for daily reminders and weekly summaries.
///
/// iOS advantage over web:
/// - More reliable delivery via APNs
/// - Rich notifications with images/actions
/// - Can schedule repeating local notifications
/// - Background app refresh for weekly summaries
actor NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission() async throws -> Bool {
        let result = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        if result {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return result
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Daily reminder

    /// Schedule a daily reminder to log weight (e.g. 8 AM)
    func scheduleDailyReminder(hour: Int = 8, minute: Int = 0) async {
        // Remove existing daily reminders first
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Time to weigh in!"
        content.body = "Quick check-in — every entry counts toward your streak."
        content.sound = .default
        content.badge = 1

        // Action buttons
        let logAction = UNNotificationAction(identifier: "LOG_WEIGHT", title: "Log Now", options: .foreground)
        let skipAction = UNNotificationAction(identifier: "SKIP", title: "Skip Today", options: .destructive)
        let category = UNNotificationCategory(identifier: "DAILY_REMINDER", actions: [logAction, skipAction], intentIdentifiers: [])
        center.setNotificationCategories([category])
        content.categoryIdentifier = "DAILY_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-reminder", content: content, trigger: trigger)

        try? await center.add(request)
    }

    /// Cancel daily reminder
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
    }

    // MARK: - Streak notifications

    /// Notify user at risk of losing streak (evening if no log today)
    func scheduleStreakReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: ["streak-reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Don't break the streak!"
        content.body = "You haven't logged today. Quick weigh-in to keep it going!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20  // 8 PM
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "streak-reminder", content: content, trigger: trigger)

        try? await center.add(request)
    }

    // MARK: - Milestone notifications

    func sendMilestoneNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "milestone-\(UUID().uuidString)", content: content, trigger: trigger)

        try? await center.add(request)
    }

    // MARK: - Clear badge

    func clearBadge() async {
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}
