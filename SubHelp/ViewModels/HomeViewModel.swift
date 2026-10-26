import SwiftUI

enum SubscriptionViewMode: String, CaseIterable {
    case list = "List"
    case calendar = "Calendar"
    case board = "Board"
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
            total + sub.frequency.monthlyAmount(for: sub.price)
        }
    }

    var totalPerYear: Decimal {
        subscriptions.reduce(Decimal.zero) { total, sub in
            total + sub.frequency.yearlyAmount(for: sub.price)
        }
    }

    /// Yearly amount saved from cancelled (unsubscribed) subscriptions.
    var unsubscribedSavedPerYear: Decimal {
        unsubscribed.reduce(Decimal.zero) { total, sub in
            total + sub.frequency.yearlyAmount(for: sub.price)
        }
    }

    @Published var selectedDate = Date()

    /// Subscriptions included in the current category filter (same order as `subscriptions`).
    var subscriptionsForDisplay: [Subscription] {
        filtered(subscriptions)
    }

    /// Cancelled subscriptions included in the current category filter.
    var unsubscribedForDisplay: [Subscription] {
        filtered(unsubscribed)
    }

    private func filtered(_ subs: [Subscription]) -> [Subscription] {
        switch categoryFilter {
        case .all:
            return subs
        case .uncategorized:
            return subs.filter { ($0.category ?? "").isEmpty }
        case .category(let name):
            return subs.filter { $0.category == name }
        }
    }

    func subscriptions(for date: Date) -> [Subscription] {
        let cal = Calendar.current
        return subscriptionsForDisplay.filter { sub in
            sub.frequency.renews(on: date, anchor: sub.nextPaymentDate, calendar: cal)
        }
    }

    func subscriptionColors(forDay day: Int, inMonth month: Date) -> [Color] {
        let cal = Calendar.current
        var parts = cal.dateComponents([.year, .month], from: month)
        parts.day = day
        guard let date = cal.date(from: parts) else { return [] }

        return subscriptionsForDisplay.compactMap { sub in
            sub.frequency.renews(on: date, anchor: sub.nextPaymentDate, calendar: cal) ? sub.color : nil
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
            total + sub.frequency.monthlyAmount(for: sub.price)
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
        var sub = sub
        let nextOrder = (subscriptions.filter { $0.stage == sub.stage }.map(\.boardOrder).max() ?? -1) + 1
        sub.boardOrder = nextOrder
        subscriptions.append(sub)
        applySorting()
        persist()
        syncCategoryFilterWithSubscriptions()
    }

    /// Subscriptions in one board column, respecting the category filter.
    func subscriptions(in stage: SubscriptionStage) -> [Subscription] {
        subscriptionsForDisplay
            .filter { $0.stage == stage }
            .sorted { lhs, rhs in
                if lhs.boardOrder != rhs.boardOrder { return lhs.boardOrder < rhs.boardOrder }
                return lhs.addedAt < rhs.addedAt
            }
    }

    /// Moves a subscription into `stage`, inserting it before `beforeID` or at the end of that column.
    @discardableResult
    func moveSubscription(_ id: UUID, to stage: SubscriptionStage, before beforeID: UUID?) -> Bool {
        guard subscriptions.contains(where: { $0.id == id }) else { return false }
        if beforeID == id { return false }

        var updated = subscriptions
        guard let movingIndex = updated.firstIndex(where: { $0.id == id }) else { return false }
        updated[movingIndex].stage = stage

        var columnIDs = updated
            .filter { $0.stage == stage && $0.id != id }
            .sorted { lhs, rhs in
                if lhs.boardOrder != rhs.boardOrder { return lhs.boardOrder < rhs.boardOrder }
                return lhs.addedAt < rhs.addedAt
            }
            .map(\.id)

        if let beforeID, let insertAt = columnIDs.firstIndex(of: beforeID) {
            columnIDs.insert(id, at: insertAt)
        } else {
            columnIDs.append(id)
        }

        for (order, columnID) in columnIDs.enumerated() {
            guard let index = updated.firstIndex(where: { $0.id == columnID }) else { continue }
            updated[index].boardOrder = order
        }

        let before = subscriptions.map { "\($0.id.uuidString)|\($0.stage.rawValue)|\($0.boardOrder)" }
        let after = updated.map { "\($0.id.uuidString)|\($0.stage.rawValue)|\($0.boardOrder)" }
        guard before != after else { return false }

        subscriptions = updated
        persist()
        return true
    }

    func updateSubscription(_ updated: Subscription) {
        guard let index = subscriptions.firstIndex(where: { $0.id == updated.id }) else { return }
        let previous = subscriptions[index]
        var merged = updated
        merged.addedAt = previous.addedAt
        if merged.stage != previous.stage {
            let nextOrder = (subscriptions.filter { $0.stage == merged.stage && $0.id != merged.id }.map(\.boardOrder).max() ?? -1) + 1
            merged.boardOrder = nextOrder
        } else {
            merged.boardOrder = previous.boardOrder
        }
        subscriptions[index] = merged
        applySorting()
        persist()
        syncCategoryFilterWithSubscriptions()
    }

    func removeSubscription(_ sub: Subscription) {
        let alreadyCancelled = unsubscribed.contains(where: { $0.id == sub.id })
        subscriptions.removeAll { $0.id == sub.id }
        if !alreadyCancelled {
            savedAmount += sub.frequency.monthlyAmount(for: sub.price)
            unsubscribed.append(sub)
        }
        applySorting()
        persist()
        syncCategoryFilterWithSubscriptions()
    }

    /// Puts a cancelled subscription back on the board in `stage`.
    @discardableResult
    func restoreSubscription(_ id: UUID, to stage: SubscriptionStage, before beforeID: UUID?) -> Bool {
        guard let index = unsubscribed.firstIndex(where: { $0.id == id }) else { return false }
        if beforeID == id { return false }
        var sub = unsubscribed.remove(at: index)
        savedAmount = Self.calculateSavedAmount(from: unsubscribed)
        sub.stage = stage
        sub.boardOrder = -1
        subscriptions.append(sub)
        if !moveSubscription(id, to: stage, before: beforeID) {
            persist()
        }
        syncCategoryFilterWithSubscriptions()
        return true
    }

    func updateUnsubscribed(_ updated: Subscription) {
        guard let index = unsubscribed.firstIndex(where: { $0.id == updated.id }) else { return }
        var merged = updated
        merged.addedAt = unsubscribed[index].addedAt
        unsubscribed[index] = merged
        savedAmount = Self.calculateSavedAmount(from: unsubscribed)
        persist()
    }

    /// Saves edits to an active subscription, or to a cancelled one. Changing a cancelled subscription’s stage puts it back on the board.
    func saveSubscriptionEdits(_ updated: Subscription) {
        if subscriptions.contains(where: { $0.id == updated.id }) {
            updateSubscription(updated)
            return
        }
        guard let previous = unsubscribed.first(where: { $0.id == updated.id }) else { return }
        if updated.stage != previous.stage {
            updateUnsubscribed(updated)
            restoreSubscription(updated.id, to: updated.stage, before: nil)
        } else {
            updateUnsubscribed(updated)
        }
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
