import Foundation
import UserNotifications

enum RenewalNotificationScheduler {
    private static let renewalCategoryIdentifier = "subhelp.renewal"

    /// Schedules local notifications for subscription renewals based on stored subscriptions and notificationDaysBefore setting.
    static func scheduleRenewalReminders() {
        let daysBefore = UserDefaults.standard.object(forKey: "notificationDaysBefore") as? Int ?? 1

        guard daysBefore >= 0 else {
            removeAllRenewalNotifications()
            return
        }

        let subscriptions = SubscriptionStorage.loadSubscriptions()
        guard !subscriptions.isEmpty else {
            removeAllRenewalNotifications()
            return
        }

        Task {
            let center = UNUserNotificationCenter.current()
            let granted = await requestPermissionIfNeeded(center: center)
            guard granted else { return }

            await removeAllRenewalNotificationsAsync(center: center)

            let cal = Calendar.current
            let now = Date()

            for sub in subscriptions {
                let triggerDate = cal.date(byAdding: .day, value: -daysBefore, to: sub.nextPaymentDate) ?? sub.nextPaymentDate
                var components = cal.dateComponents([.year, .month, .day], from: triggerDate)
                components.hour = 9
                components.minute = 0

                if cal.date(from: components) ?? triggerDate < now {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Subscription renewal"
                let currency = UserDefaults.standard.string(forKey: "currencyCode") ?? "GBP"
                let priceText = sub.price.formatted(.currency(code: currency).locale(.autoupdatingCurrent))
                content.body = "\(sub.name) renews \(priceText) on \(formatDate(sub.nextPaymentDate))"
                content.sound = .default
                content.categoryIdentifier = Self.renewalCategoryIdentifier

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "subhelp.renewal.\(sub.id.uuidString)",
                    content: content,
                    trigger: trigger
                )

                try? await center.add(request)
            }
        }
    }

    private static func requestPermissionIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            return true
        case .provisional, .ephemeral:
            // Already allowed to deliver (quietly or in limited contexts); do not call request again.
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ?? false
        @unknown default:
            return false
        }
    }

    private static func removeAllRenewalNotifications() {
        Task {
            await removeAllRenewalNotificationsAsync(center: UNUserNotificationCenter.current())
        }
    }

    private static func removeAllRenewalNotificationsAsync(center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let renewalIds = pending
            .filter { $0.identifier.hasPrefix("subhelp.renewal.") }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: renewalIds)
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
