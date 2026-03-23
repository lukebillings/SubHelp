import Foundation
import SwiftUI
import UIKit

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
    }

    func toSubscription() -> Subscription {
        Subscription(
            id: id,
            name: name,
            nextPaymentDate: nextPaymentDate,
            price: price,
            color: Color(red: colorR, green: colorG, blue: colorB),
            frequency: BillingFrequency(rawValue: frequency) ?? .monthly,
            category: category
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

// MARK: - Persistence container

private struct PersistedData: Codable {
    var subscriptions: [PersistedSubscription]
    var unsubscribed: [PersistedSubscription]
}

// MARK: - Subscription storage

enum SubscriptionStorage {
    private static let subscriptionsKey = "subhelp.subscriptions"
    private static let unsubscribedKey = "subhelp.unsubscribed"

    static func loadSubscriptions() -> [Subscription] {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsKey),
              let decoded = try? JSONDecoder().decode([PersistedSubscription].self, from: data) else {
            return []
        }
        return decoded.map { $0.toSubscription() }
    }

    static func loadUnsubscribed() -> [Subscription] {
        guard let data = UserDefaults.standard.data(forKey: unsubscribedKey),
              let decoded = try? JSONDecoder().decode([PersistedSubscription].self, from: data) else {
            return []
        }
        return decoded.map { $0.toSubscription() }
    }

    static func save(subscriptions: [Subscription]) {
        let persisted = subscriptions.map { PersistedSubscription(from: $0) }
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: subscriptionsKey)
        }
    }

    static func save(unsubscribed: [Subscription]) {
        let persisted = unsubscribed.map { PersistedSubscription(from: $0) }
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: unsubscribedKey)
        }
    }
}
