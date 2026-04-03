import SwiftUI

enum SubscriptionViewMode: String, CaseIterable {
    case list = "List"
    case calendar = "Calendar"
}

enum SortOption: String, CaseIterable {
    case dateAdded = "Date added"
    case renewalAsc = "Renewal date"
    case renewalDesc = "Renewal latest"
    case nameAsc = "Name A–Z"
    case nameDesc = "Name Z–A"
    case priceAsc = "Price Low–High"
    case priceDesc = "Price High–Low"
}

/// Shown in the subscriptions list filter menu (`All`, `Uncategorized`, or a category name).
enum SubscriptionListCategoryFilter: Equatable, Hashable {
    case all
    case uncategorized
    case category(String)

    var displayTitle: String {
        switch self {
        case .all: return "All"
        case .uncategorized: return "Uncategorized"
        case .category(let name): return name
        }
    }

    static var menuOptions: [SubscriptionListCategoryFilter] {
        [.all, .uncategorized] + SubscriptionCategory.allCases.map { .category($0.rawValue) }
    }
}

final class HomeViewModel: ObservableObject {
    @Published var subscriptions: [Subscription]
    @Published var unsubscribed: [Subscription] = []
    @Published var viewMode: SubscriptionViewMode = .list
    @Published var savedAmount: Decimal = 23
    @Published var sortOption: SortOption = .dateAdded {
        didSet { applySorting() }
    }

    @Published var categoryFilter: SubscriptionListCategoryFilter = .all

    private var externalDataObserver: NSObjectProtocol?

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

    /// Subscriptions included in the current category filter (same order as `subscriptions`).
    var subscriptionsForDisplay: [Subscription] {
        switch categoryFilter {
        case .all:
            return subscriptions
        case .uncategorized:
            return subscriptions.filter { ($0.category ?? "").isEmpty }
        case .category(let name):
            return subscriptions.filter { $0.category == name }
        }
    }

    func subscriptions(for date: Date) -> [Subscription] {
        let cal = Calendar.current
        return subscriptionsForDisplay.filter { sub in
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

        return subscriptionsForDisplay.compactMap { sub in
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

        externalDataObserver = NotificationCenter.default.addObserver(
            forName: .subhelpSubscriptionsDidChangeExternally,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromPersistentStorage()
        }

        applySorting()
    }

    deinit {
        if let externalDataObserver {
            NotificationCenter.default.removeObserver(externalDataObserver)
        }
    }

    func reloadFromPersistentStorage() {
        subscriptions = SubscriptionStorage.loadSubscriptions()
        unsubscribed = SubscriptionStorage.loadUnsubscribed()
        savedAmount = Self.calculateSavedAmount(from: unsubscribed)
        applySorting()
        syncCategoryFilterWithSubscriptions()
    }

    func resetToFreshInstallState() {
        subscriptions = []
        unsubscribed = []
        savedAmount = 0
        categoryFilter = .all
        sortOption = .dateAdded
        viewMode = .list
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
        SubscriptionStorage.saveAll(subscriptions: subscriptions, unsubscribed: unsubscribed)
        RenewalNotificationScheduler.scheduleRenewalReminders()
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    static var sampleSubscriptions: [Subscription] {
        let rows: [(String, Date, Decimal, Color, BillingFrequency?)] = [
            ("Spotify", date(2025, 6, 3), 9.99, Color(red: 0.11, green: 0.84, blue: 0.38), nil),
            ("Netflix", date(2025, 6, 12), 15.99, Color(red: 0.89, green: 0.15, blue: 0.21), nil),
            ("Disney+", date(2025, 6, 18), 7.99, Color(red: 0.0, green: 0.48, blue: 0.9), nil),
            ("Prime", date(2025, 9, 22), 95.00, Color(red: 0.24, green: 0.6, blue: 0.87), .yearly),
            ("YouTube Premium", date(2025, 6, 7), 12.99, Color(red: 0.93, green: 0.11, blue: 0.14), nil),
            ("iCloud+", date(2025, 6, 1), 2.99, Color(red: 0.35, green: 0.78, blue: 0.98), nil),
            ("Gym", date(2025, 6, 15), 29.99, Color(red: 0.6, green: 0.35, blue: 0.71), nil),
            ("ChatGPT Plus", date(2025, 6, 24), 19.99, Color(red: 0.29, green: 0.65, blue: 0.55), nil),
            ("Xbox Game Pass", date(2025, 6, 10), 14.99, Color(red: 0.07, green: 0.49, blue: 0.17), nil)
        ]
        return rows.enumerated().map { index, row in
            Subscription(
                name: row.0,
                nextPaymentDate: row.1,
                price: row.2,
                color: row.3,
                frequency: row.4 ?? .monthly,
                addedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
    }

    func addSubscription(_ sub: Subscription) {
        subscriptions.append(sub)
        applySorting()
        persist()
        syncCategoryFilterWithSubscriptions()
    }

    func updateSubscription(_ updated: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == updated.id }) {
            var merged = updated
            merged.addedAt = subscriptions[index].addedAt
            subscriptions[index] = merged
            applySorting()
            persist()
            syncCategoryFilterWithSubscriptions()
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
        applySorting()
        persist()
        syncCategoryFilterWithSubscriptions()
    }

    func applySorting() {
        switch sortOption {
        case .dateAdded:
            subscriptions.sort { $0.addedAt < $1.addedAt }
        case .renewalAsc:
            subscriptions.sort { $0.nextPaymentDate < $1.nextPaymentDate }
        case .renewalDesc:
            subscriptions.sort { $0.nextPaymentDate > $1.nextPaymentDate }
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

extension HomeViewModel {
    /// Category filter choices that match at least one subscription (plus All / Uncategorized when relevant).
    var categoryFilterMenuOptions: [SubscriptionListCategoryFilter] {
        var options: [SubscriptionListCategoryFilter] = [.all]
        if subscriptions.contains(where: { ($0.category ?? "").isEmpty }) {
            options.append(.uncategorized)
        }
        let usedNames = Set(subscriptions.compactMap { $0.category }.filter { !$0.isEmpty })
        let canonicalOrdered = SubscriptionCategory.allCases.map(\.rawValue).filter { usedNames.contains($0) }
        options.append(contentsOf: canonicalOrdered.map { SubscriptionListCategoryFilter.category($0) })
        let known = Set(SubscriptionCategory.allCases.map(\.rawValue))
        for name in usedNames.subtracting(known).sorted() {
            options.append(.category(name))
        }
        return options
    }

    /// Resets the filter to All if the current selection no longer matches any subscription.
    func syncCategoryFilterWithSubscriptions() {
        let valid = Set(categoryFilterMenuOptions)
        if !valid.contains(categoryFilter) {
            categoryFilter = .all
        }
    }
}
