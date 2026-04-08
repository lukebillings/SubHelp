import Foundation
import SwiftUI
import UIKit

extension Notification.Name {
    static let subhelpSubscriptionsDidChangeExternally = Notification.Name("subhelpSubscriptionsDidChangeExternally")
    static let subhelpResetAllData = Notification.Name("subhelpResetAllData")
}

// MARK: - Persisted subscription (Codable)

private struct PersistedSubscription: Codable {
    let id: UUID
    var name: String
    var nextPaymentDate: Date
    var price: Decimal
    var colorR: Double
    var colorG: Double
    var colorB: Double
    var frequency: String
    var category: String?
    /// Older app versions did not store this; see `loadSubscriptions` migration.
    var addedAt: Date?

    init(from sub: Subscription) {
        self.id = sub.id
        self.name = sub.name
        self.nextPaymentDate = sub.nextPaymentDate
        self.price = sub.price
        let (r, g, b) = sub.color.rgbComponents
        self.colorR = r
        self.colorG = g
        self.colorB = b
        self.frequency = sub.frequency.rawValue
        self.category = sub.category
        self.addedAt = sub.addedAt
    }

    func toSubscription(legacyListIndex: Int?) -> Subscription {
        let resolvedAddedAt = addedAt ?? Date(timeIntervalSince1970: TimeInterval(legacyListIndex ?? 0))
        return Subscription(
            id: id,
            name: name,
            nextPaymentDate: nextPaymentDate,
            price: price,
            color: Color(red: colorR, green: colorG, blue: colorB),
            frequency: BillingFrequency(rawValue: frequency) ?? .monthly,
            category: category,
            addedAt: resolvedAddedAt
        )
    }
}

// MARK: - Color RGB extraction

private extension Color {
    var rgbComponents: (Double, Double, Double) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Double(r), Double(g), Double(b))
        }
        return (0.5, 0.5, 0.5)
    }
}

// MARK: - Subscription storage (local + iCloud Key-Value)

/// UserDefaults keys shared outside `SubscriptionStorage`.
enum SubHelpAppStorageKey {
    /// Set when the user finishes the current onboarding (benefits → currency → reminders). Used to migrate pre–onboarding-v2 installs once.
    static let hasCompletedOnboardingV2 = "subhelp.hasCompletedOnboardingV2"
}

enum SubscriptionStorage {
    static let subscriptionsKey = "subhelp.subscriptions"
    static let unsubscribedKey = "subhelp.unsubscribed"
    private static let revisionKey = "subhelp.dataRevision"

    private static var ubiquitous: NSUbiquitousKeyValueStore { NSUbiquitousKeyValueStore.default }

    static func registerForCloudUpdates() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitous,
            queue: .main
        ) { _ in
            applyIncomingCloudChangesIfNeeded()
        }
        ubiquitous.synchronize()
    }

    /// Call once at launch after local `HomeViewModel` is ready to observe `subhelpSubscriptionsDidChangeExternally`.
    static func mergeFromCloudOnLaunch() {
        ubiquitous.synchronize()
        applyIncomingCloudChangesIfNeeded()
    }

    private static func bumpRevision() {
        let next = max(Date().timeIntervalSince1970, UserDefaults.standard.double(forKey: revisionKey) + 1)
        UserDefaults.standard.set(next, forKey: revisionKey)
        ubiquitous.set(next, forKey: revisionKey)
    }

    static func loadSubscriptions() -> [Subscription] {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsKey),
              let decoded = try? JSONDecoder().decode([PersistedSubscription].self, from: data) else {
            return []
        }
        return decoded.enumerated().map { index, p in
            let legacyIndex = p.addedAt == nil ? index : nil
            return p.toSubscription(legacyListIndex: legacyIndex)
        }
    }

    static func loadUnsubscribed() -> [Subscription] {
        guard let data = UserDefaults.standard.data(forKey: unsubscribedKey),
              let decoded = try? JSONDecoder().decode([PersistedSubscription].self, from: data) else {
            return []
        }
        return decoded.enumerated().map { index, p in
            let legacyIndex = p.addedAt == nil ? index : nil
            return p.toSubscription(legacyListIndex: legacyIndex)
        }
    }

    static func saveAll(subscriptions: [Subscription], unsubscribed: [Subscription]) {
        let subData = try? JSONEncoder().encode(subscriptions.map { PersistedSubscription(from: $0) })
        let unsubData = try? JSONEncoder().encode(unsubscribed.map { PersistedSubscription(from: $0) })
        if let subData {
            UserDefaults.standard.set(subData, forKey: subscriptionsKey)
            ubiquitous.set(subData, forKey: subscriptionsKey)
        }
        if let unsubData {
            UserDefaults.standard.set(unsubData, forKey: unsubscribedKey)
            ubiquitous.set(unsubData, forKey: unsubscribedKey)
        }
        bumpRevision()
        ubiquitous.synchronize()
    }

    private static func applyIncomingCloudChangesIfNeeded() {
        ubiquitous.synchronize()

        let remoteRev = ubiquitous.double(forKey: revisionKey)
        let localRev = UserDefaults.standard.double(forKey: revisionKey)
        let localSubData = UserDefaults.standard.data(forKey: subscriptionsKey)
        let cloudSubData = ubiquitous.data(forKey: subscriptionsKey)

        let shouldApply = remoteRev > localRev
            || (localSubData == nil && cloudSubData != nil)

        guard shouldApply else { return }

        if let data = cloudSubData {
            UserDefaults.standard.set(data, forKey: subscriptionsKey)
        }
        if let data = ubiquitous.data(forKey: unsubscribedKey) {
            UserDefaults.standard.set(data, forKey: unsubscribedKey)
        }
        if remoteRev > 0 {
            UserDefaults.standard.set(remoteRev, forKey: revisionKey)
        }

        NotificationCenter.default.post(name: .subhelpSubscriptionsDidChangeExternally, object: nil)
    }

    /// Clears subscription data, iCloud copies, and common user defaults (full reset from Settings).
    static func resetAllAppDataToFreshInstall() {
        UserDefaults.standard.removeObject(forKey: subscriptionsKey)
        UserDefaults.standard.removeObject(forKey: unsubscribedKey)
        UserDefaults.standard.removeObject(forKey: revisionKey)

        ubiquitous.removeObject(forKey: subscriptionsKey)
        ubiquitous.removeObject(forKey: unsubscribedKey)
        ubiquitous.removeObject(forKey: revisionKey)
        ubiquitous.synchronize()

        UserDefaults.standard.set(false, forKey: "hasCompletedPaywall")
        UserDefaults.standard.set(false, forKey: "hasCompletedCurrencyOnboarding")
        UserDefaults.standard.removeObject(forKey: SubHelpAppStorageKey.hasCompletedOnboardingV2)
        UserDefaults.standard.set(false, forKey: "subhelp.didCompleteNotificationSetup")
        UserDefaults.standard.set("GBP", forKey: "currencyCode")
        UserDefaults.standard.set(1, forKey: "notificationDaysBefore")
        UserDefaults.standard.removeObject(forKey: RenewalNotificationScheduler.notificationsEnabledKey)
        UserDefaults.standard.removeObject(forKey: SubHelpHaptics.userDefaultsKey)
        UserDefaults.standard.set(SubscriptionTier.free.rawValue, forKey: "subscriptionTier")
        UserDefaults.standard.removeObject(forKey: "subhelp.sessionPaywallActivateCount")
    }
}
