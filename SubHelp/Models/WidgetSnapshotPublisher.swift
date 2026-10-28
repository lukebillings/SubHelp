import Foundation
import WidgetKit

enum WidgetSnapshotPublisher {
    /// Copies active subscriptions into the App Group and asks the widget to reload.
    static func refreshFromStorage() {
        let currency = UserDefaults.standard.string(forKey: "currencyCode") ?? "GBP"
        let records = SubscriptionStorage.loadSubscriptions().map { subscription in
            WidgetSubscriptionRecord(
                id: subscription.id,
                name: subscription.name,
                nextPaymentDate: subscription.nextPaymentDate,
                price: subscription.price,
                frequency: subscription.frequency.rawValue,
                isTrial: subscription.isTrial,
                trialEndDate: subscription.trialEndDate
            )
        }
        WidgetSnapshotStore.save(WidgetSnapshot(currencyCode: currency, subscriptions: records))
        WidgetCenter.shared.reloadTimelines(ofKind: SubHelpAppGroup.widgetKind)
    }
}
