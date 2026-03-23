import SwiftUI

enum SubscriptionViewMode: String, CaseIterable {
    case list = "List"
    case calendar = "Calendar"
}

enum SortOption: String, CaseIterable {
    case nameAsc = "Name A–Z"
    case nameDesc = "Name Z–A"
    case priceAsc = "Price Low–High"
    case priceDesc = "Price High–Low"
}

final class HomeViewModel: ObservableObject {
    @Published var subscriptions: [Subscription]
    @Published var unsubscribed: [Subscription] = []
    @Published var viewMode: SubscriptionViewMode = .list
    @Published var savedAmount: Decimal = 23
    @Published var sortOption: SortOption = .nameAsc {
        didSet { applySorting() }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        return f
    }()

    var totalPerMonth: Decimal {
        subscriptions.reduce(Decimal.zero) { total, sub in
            switch sub.frequency {
            case .weekly: return total + (sub.price * 52 / 12)
            case .monthly: return total + sub.price
            case .yearly: return total + (sub.price / 12)
            }
        }
    }

    var totalPerYear: Decimal {
        subscriptions.reduce(Decimal.zero) { total, sub in
            switch sub.frequency {
            case .weekly: return total + (sub.price * 52)
            case .monthly: return total + (sub.price * 12)
            case .yearly: return total + sub.price
            }
        }
    }

    /// Yearly amount saved from cancelled (unsubscribed) subscriptions.
    var unsubscribedSavedPerYear: Decimal {
        unsubscribed.reduce(Decimal.zero) { total, sub in
            switch sub.frequency {
            case .weekly: return total + (sub.price * 52)
            case .monthly: return total + (sub.price * 12)
            case .yearly: return total + sub.price
            }
        }
    }

    @Published var selectedDate = Date()

    func subscriptions(for date: Date) -> [Subscription] {
        let cal = Calendar.current
        return subscriptions.filter { sub in
            let subDay = cal.component(.day, from: sub.nextPaymentDate)
            let dateDay = cal.component(.day, from: date)
            if sub.frequency == .monthly {
                return subDay == dateDay
            } else {
                return cal.isDate(sub.nextPaymentDate, equalTo: date, toGranularity: .day)
            }
        }
    }

    func subscriptionColors(forDay day: Int, inMonth month: Date) -> [Color] {
        let cal = Calendar.current
        let monthComp = cal.component(.month, from: month)
        let yearComp = cal.component(.year, from: month)

        return subscriptions.compactMap { sub in
            let subDay = cal.component(.day, from: sub.nextPaymentDate)
            if sub.frequency == .monthly {
                return subDay == day ? sub.color : nil
            } else {
                let subMonth = cal.component(.month, from: sub.nextPaymentDate)
                let subYear = cal.component(.year, from: sub.nextPaymentDate)
                return (subDay == day && subMonth == monthComp && subYear == yearComp) ? sub.color : nil
            }
        }
    }

    func daysInMonth(_ date: Date) -> Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    func firstWeekdayOfMonth(_ date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        let firstDay = cal.date(from: comps)!
        return (cal.component(.weekday, from: firstDay) + 5) % 7 // Monday = 0
    }

    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedDate)
    }

    init(subscriptions: [Subscription]? = nil) {
        if let subs = subscriptions {
            self.subscriptions = subs
            self.unsubscribed = []
            self.savedAmount = 0
        } else {
            self.subscriptions = SubscriptionStorage.loadSubscriptions()
            self.unsubscribed = SubscriptionStorage.loadUnsubscribed()
            self.savedAmount = Self.calculateSavedAmount(from: self.unsubscribed)
        }
    }

    private static func calculateSavedAmount(from unsubscribed: [Subscription]) -> Decimal {
        unsubscribed.reduce(Decimal.zero) { total, sub in
            switch sub.frequency {
            case .weekly: return total + (sub.price * 52 / 12)
            case .monthly: return total + sub.price
            case .yearly: return total + (sub.price / 12)
            }
        }
    }

    private func persist() {
        SubscriptionStorage.save(subscriptions: subscriptions)
        SubscriptionStorage.save(unsubscribed: unsubscribed)
        RenewalNotificationScheduler.scheduleRenewalReminders()
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    static var sampleSubscriptions: [Subscription] {
        return [
            Subscription(name: "Spotify", nextPaymentDate: date(2025, 6, 3), price: 9.99, color: Color(red: 0.11, green: 0.84, blue: 0.38)),
            Subscription(name: "Netflix", nextPaymentDate: date(2025, 6, 12), price: 15.99, color: Color(red: 0.89, green: 0.15, blue: 0.21)),
            Subscription(name: "Disney+", nextPaymentDate: date(2025, 6, 18), price: 7.99, color: Color(red: 0.0, green: 0.48, blue: 0.9)),
            Subscription(name: "Prime", nextPaymentDate: date(2025, 9, 22), price: 95.00, color: Color(red: 0.24, green: 0.6, blue: 0.87), frequency: .yearly),
            Subscription(name: "YouTube Premium", nextPaymentDate: date(2025, 6, 7), price: 12.99, color: Color(red: 0.93, green: 0.11, blue: 0.14)),
            Subscription(name: "iCloud+", nextPaymentDate: date(2025, 6, 1), price: 2.99, color: Color(red: 0.35, green: 0.78, blue: 0.98)),
            Subscription(name: "Gym", nextPaymentDate: date(2025, 6, 15), price: 29.99, color: Color(red: 0.6, green: 0.35, blue: 0.71)),
            Subscription(name: "ChatGPT Plus", nextPaymentDate: date(2025, 6, 24), price: 19.99, color: Color(red: 0.29, green: 0.65, blue: 0.55)),
            Subscription(name: "Xbox Game Pass", nextPaymentDate: date(2025, 6, 10), price: 14.99, color: Color(red: 0.07, green: 0.49, blue: 0.17))
        ]
    }

    func addSubscription(_ sub: Subscription) {
        subscriptions.append(sub)
        persist()
    }

    func updateSubscription(_ updated: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == updated.id }) {
            subscriptions[index] = updated
            persist()
        }
    }

    func removeSubscription(_ sub: Subscription) {
        switch sub.frequency {
        case .weekly: savedAmount += (sub.price * 52 / 12)
        case .monthly: savedAmount += sub.price
        case .yearly: savedAmount += (sub.price / 12)
        }
        subscriptions.removeAll { $0.id == sub.id }
        if !unsubscribed.contains(where: { $0.id == sub.id }) {
            unsubscribed.append(sub)
        }
        persist()
    }

    func applySorting() {
        switch sortOption {
        case .nameAsc:
            subscriptions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            subscriptions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .priceAsc:
            subscriptions.sort { $0.price < $1.price }
        case .priceDesc:
            subscriptions.sort { $0.price > $1.price }
        }
    }

    func nextPaymentString(for date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        let formatted = Self.dateFormatter.string(from: date) // "7 June"
        let month = formatted.replacingOccurrences(of: "^[0-9]+ ", with: "", options: .regularExpression)
        return "\(day)\(suffix) \(month)"
    }
}
