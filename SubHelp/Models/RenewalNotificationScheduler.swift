import Foundation
import UserNotifications

enum TrialDecision {
    case keep
    case cancel
    case ask

    static let keepAction = "subhelp.trial.keep"
    static let cancelAction = "subhelp.trial.cancel"
}

enum TrialPromptCenter {
    static let notification = Notification.Name("subhelp.trialDecision")
    static var pending: (id: UUID, decision: TrialDecision)?
}

enum RenewalNotificationScheduler {
    private static let renewalCategoryIdentifier = "subhelp.renewal"
    private static let trialCategoryIdentifier = "subhelp.trialEnd"
    private static let notificationSetupKey = "subhelp.didCompleteNotificationSetup"

    static func registerCategories() {
        let keep = UNNotificationAction(identifier: TrialDecision.keepAction, title: "I kept it", options: [.foreground])
        let cancel = UNNotificationAction(identifier: TrialDecision.cancelAction, title: "I cancelled", options: [.destructive, .foreground])
        let trial = UNNotificationCategory(
            identifier: trialCategoryIdentifier,
            actions: [keep, cancel],
            intentIdentifiers: [],
            options: []
        )
        let renewal = UNNotificationCategory(
            identifier: renewalCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([trial, renewal])
    }

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

            registerCategories()

            let cal = Calendar.current
            let now = Date()
            let currency = UserDefaults.standard.string(forKey: "currencyCode") ?? "GBP"

            for sub in subscriptions {
                if sub.isTrial, let trialEnd = sub.trialEndDate {
                    await scheduleTrialReminder(
                        for: sub,
                        trialEnd: trialEnd,
                        daysBefore: daysBefore,
                        currency: currency,
                        calendar: cal,
                        now: now,
                        center: center
                    )
                    continue
                }

                let triggerDate = cal.date(byAdding: .day, value: -daysBefore, to: sub.nextPaymentDate) ?? sub.nextPaymentDate
                guard let morning = morning(on: triggerDate, calendar: cal), morning > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Subscription renewal"
                let priceText = CurrencyOptions.formatPresentation(amount: sub.price, currencyCode: currency)
                content.body = "\(sub.name) renews \(priceText) on \(formatDate(sub.nextPaymentDate))"
                content.sound = .default
                content.categoryIdentifier = Self.renewalCategoryIdentifier

                let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: morning), repeats: false)
                let request = UNNotificationRequest(
                    identifier: "subhelp.renewal.\(sub.id.uuidString)",
                    content: content,
                    trigger: trigger
                )

                try? await center.add(request)
            }
        }
    }

    private static func scheduleTrialReminder(
        for sub: Subscription,
        trialEnd: Date,
        daysBefore: Int,
        currency: String,
        calendar: Calendar,
        now: Date,
        center: UNUserNotificationCenter
    ) async {
        let lead = calendar.date(byAdding: .day, value: -daysBefore, to: trialEnd) ?? trialEnd
        let preferred = morning(on: lead, calendar: calendar)
        let onTheDay = morning(on: trialEnd, calendar: calendar)
        let fireAt = [preferred, onTheDay].compactMap { $0 }.first { $0 > now }
        guard let fireAt else { return }

        let priceText = CurrencyOptions.formatPresentation(amount: sub.price, currencyCode: currency)
        let warnsEarly = calendar.isDate(fireAt, inSameDayAs: lead) && !calendar.isDate(lead, inSameDayAs: trialEnd)
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = trialCategoryIdentifier
        content.userInfo = ["subscriptionID": sub.id.uuidString]
        if warnsEarly {
            content.title = "Free trial ending"
            content.body = "\(sub.name) trial ends \(formatDate(trialEnd)). You'll be charged \(priceText) \(sub.frequency.periodPhrase) unless you cancel."
        } else {
            content.title = "Trial ended"
            content.body = "Did you cancel \(sub.name), or are you keeping it? Keeping it adds \(priceText) \(sub.frequency.periodPhrase) to your list."
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "subhelp.trial.\(sub.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private static func morning(on day: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components)
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
            .filter { $0.identifier.hasPrefix("subhelp.renewal.") || $0.identifier.hasPrefix("subhelp.trial.") }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: renewalIds)
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
