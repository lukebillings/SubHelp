import Foundation
import UserNotifications

enum RenewalNotificationScheduler {
    private static let renewalCategoryIdentifier = "subhelp.renewal"
    private static let notificationSetupKey = "subhelp.didCompleteNotificationSetup"

    /// Master switch: when `false`, no SubHelp notifications are scheduled (renewal reminders cleared).
    static let notificationsEnabledKey = "subhelp.notificationsEnabled"

    /// Master toggle when set; otherwise legacy heuristic (`notificationDaysBefore == -1` meant no renewal scheduling).
    static func notificationsEnabledInStorage() -> Bool {
        if UserDefaults.standard.object(forKey: notificationsEnabledKey) != nil {
            return UserDefaults.standard.bool(forKey: notificationsEnabledKey)
        }
        let days = UserDefaults.standard.object(forKey: "notificationDaysBefore") as? Int ?? 1
        return days >= 0
    }

    /// Schedules local notifications for subscription renewals based on stored subscriptions and notificationDaysBefore setting.
    static func scheduleRenewalReminders() {
        guard notificationsEnabledInStorage() else {
            removeAllRenewalNotifications()
            return
        }

        guard UserDefaults.standard.bool(forKey: notificationSetupKey) else { return }

        let daysBefore = UserDefaults.standard.object(forKey: "notificationDaysBefore") as? Int ?? 1

        // `-1` (“Never” in Settings): keep app notifications allowed, but do not schedule renewal reminders.
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
            let granted = await authorizationAllowsScheduling(center: center)
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
                let priceText = CurrencyOptions.formatPresentation(amount: sub.price, currencyCode: currency)
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

    /// Used after onboarding when the user opts out of reminders.
    private static func removeAllRenewalNotifications() {
        Task {
            await removeAllRenewalNotificationsAsync(center: UNUserNotificationCenter.current())
        }
    }

    /// Does not call `requestAuthorization`; onboarding or Settings handles the system prompt.
    private static func authorizationAllowsScheduling(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
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
