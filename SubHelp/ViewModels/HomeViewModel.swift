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
            sub.isTrial ? total : total + sub.frequency.monthlyAmount(for: sub.price)
        }
    }

    var totalPerYear: Decimal {
        subscriptions.reduce(Decimal.zero) { total, sub in
            sub.isTrial ? total : total + sub.frequency.yearlyAmount(for: sub.price)
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
            sub.fallsOn(date, calendar: cal)
        }
    }

    func subscriptionColors(forDay day: Int, inMonth month: Date) -> [Color] {
        let cal = Calendar.current
        var parts = cal.dateComponents([.year, .month], from: month)
        parts.day = day
        guard let date = cal.date(from: parts) else { return [] }

        return subscriptionsForDisplay.compactMap { sub in
            sub.fallsOn(date, calendar: cal) ? sub.color : nil
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

    init(subscriptions: [Subscription]? = nil, unsubscribed explicitUnsubscribed: [Subscription]? = nil) {
        if let subs = subscriptions {
            self.subscriptions = subs
            self.unsubscribed = explicitUnsubscribed ?? []
            self.savedAmount = Self.calculateSavedAmount(from: self.unsubscribed)
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

    /// Preview data. Every category has at least three subscriptions, and every board column has at least three.
    static var sampleSubscriptions: [Subscription] {
        makeSamples(sampleRows)
    }

    /// Cancelled column on the board. Kept separate so they stay off the active list.
    static var sampleCancelledSubscriptions: [Subscription] {
        makeSamples(sampleCancelledRows)
    }

    private struct SampleRow {
        var name: String
        var day: Date
        var price: Decimal
        var color: Color
        var frequency: BillingFrequency = .monthly
        var category: SubscriptionCategory
        var stage: SubscriptionStage
        var notes: String = ""
        var isTrial: Bool = false
    }

    private static let sampleRows: [SampleRow] = [
        SampleRow(name: "Spotify", day: date(2026, 11, 3), price: 10.99, color: Color(red: 0.11, green: 0.84, blue: 0.38), category: .streaming, stage: .keep),
        SampleRow(name: "Netflix", day: date(2026, 11, 12), price: 15.99, color: Color(red: 0.89, green: 0.15, blue: 0.21), category: .streaming, stage: .needsCancel),
        SampleRow(name: "Disney+", day: date(2026, 11, 18), price: 7.99, color: Color(red: 0.0, green: 0.48, blue: 0.9), category: .streaming, stage: .switchProvider),
        SampleRow(name: "YouTube Premium", day: date(2026, 11, 7), price: 12.99, color: Color(red: 0.93, green: 0.11, blue: 0.14), category: .streaming, stage: .discount),

        SampleRow(name: "ChatGPT Plus", day: date(2026, 11, 24), price: 19.99, color: Color(red: 0.0, green: 0.68, blue: 0.58), category: .ai, stage: .keep),
        SampleRow(name: "Claude Pro", day: date(2026, 11, 8), price: 19.99, color: Color(red: 0.4, green: 0.2, blue: 0.6), category: .ai, stage: .needsCancel, isTrial: true),
        SampleRow(name: "Gemini Advanced", day: date(2026, 11, 16), price: 19.99, color: Color(red: 0.26, green: 0.52, blue: 0.96), category: .ai, stage: .switchProvider),

        SampleRow(name: "PlayStation Plus", day: date(2026, 11, 4), price: 6.99, color: Color(red: 0.0, green: 0.32, blue: 0.65), category: .gaming, stage: .keep),
        SampleRow(name: "Nintendo Switch Online", day: date(2026, 11, 19), price: 3.49, color: Color(red: 0.89, green: 0.15, blue: 0.15), category: .gaming, stage: .needsCancel),
        SampleRow(name: "Xbox Game Pass", day: date(2026, 11, 10), price: 14.99, color: Color(red: 0.13, green: 0.69, blue: 0.30), category: .gaming, stage: .discount),

        SampleRow(name: "Instacart+", day: date(2026, 11, 21), price: 9.99, color: Color(red: 0.0, green: 0.62, blue: 0.38), category: .ecommerce, stage: .keep),
        SampleRow(name: "Amazon Prime", day: date(2026, 9, 22), price: 95.00, color: Color(red: 0.24, green: 0.6, blue: 0.87), frequency: .yearly, category: .ecommerce, stage: .switchProvider),
        SampleRow(name: "Uber One", day: date(2026, 11, 6), price: 5.99, color: Color(red: 0.12, green: 0.12, blue: 0.12), category: .ecommerce, stage: .discount),

        SampleRow(name: "Ring Protect", day: date(2026, 11, 2), price: 3.99, color: Color(red: 0.0, green: 0.48, blue: 0.9), category: .home, stage: .needsCancel),
        SampleRow(name: "Nest Aware", day: date(2026, 11, 14), price: 6.00, color: Color(red: 0.26, green: 0.52, blue: 0.96), category: .home, stage: .switchProvider),
        SampleRow(name: "SimpliSafe", day: date(2026, 11, 27), price: 17.99, color: Color(red: 0.85, green: 0.22, blue: 0.28), category: .home, stage: .discount),

        SampleRow(name: "OneDrive", day: date(2026, 11, 1), price: 1.99, color: Color(red: 0.0, green: 0.47, blue: 0.84), category: .cloudStorage, stage: .keep),
        SampleRow(name: "Google One", day: date(2026, 11, 9), price: 1.99, color: Color(red: 0.26, green: 0.52, blue: 0.96), category: .cloudStorage, stage: .needsCancel),
        SampleRow(name: "Dropbox", day: date(2026, 11, 23), price: 9.99, color: Color(red: 0.0, green: 0.47, blue: 0.95), category: .cloudStorage, stage: .switchProvider),

        SampleRow(name: "Notion", day: date(2026, 11, 5), price: 8.99, color: Color(red: 0.15, green: 0.15, blue: 0.15), category: .productivity, stage: .keep),
        SampleRow(name: "Adobe Creative Cloud", day: date(2026, 11, 11), price: 54.99, color: Color(red: 0.95, green: 0.33, blue: 0.13), category: .productivity, stage: .needsCancel, notes: "Only using Photoshop"),
        SampleRow(name: "Microsoft 365", day: date(2026, 11, 17), price: 5.99, color: Color(red: 0.0, green: 0.47, blue: 0.84), category: .productivity, stage: .discount),

        SampleRow(name: "Strava", day: date(2026, 11, 13), price: 5.99, color: Color(red: 0.94, green: 0.33, blue: 0.13), category: .health, stage: .keep),
        SampleRow(name: "Gym", day: date(2026, 11, 15), price: 29.99, color: Color(red: 0.6, green: 0.35, blue: 0.71), category: .health, stage: .switchProvider, notes: "Haven't been in months"),
        SampleRow(name: "Headspace", day: date(2026, 11, 20), price: 9.99, color: Color(red: 0.96, green: 0.6, blue: 0.2), category: .health, stage: .discount),

        SampleRow(name: "Duolingo Plus", day: date(2026, 11, 25), price: 6.99, color: Color(red: 0.0, green: 0.82, blue: 0.52), category: .learning, stage: .needsCancel),
        SampleRow(name: "Coursera Plus", day: date(2026, 3, 4), price: 399.00, color: Color(red: 0.0, green: 0.45, blue: 0.74), frequency: .yearly, category: .learning, stage: .switchProvider),
        SampleRow(name: "Kindle Unlimited", day: date(2026, 11, 28), price: 9.99, color: Color(red: 0.0, green: 0.48, blue: 0.0), category: .learning, stage: .discount),

        SampleRow(name: "1Password", day: date(2026, 11, 2), price: 2.99, color: Color(red: 0.05, green: 0.45, blue: 0.95), category: .other, stage: .keep),
        SampleRow(name: "New York Times", day: date(2026, 11, 26), price: 17.00, color: Color(red: 0.12, green: 0.12, blue: 0.12), category: .other, stage: .needsCancel),
        SampleRow(name: "Patreon", day: date(2026, 11, 22), price: 5.00, color: Color(red: 0.98, green: 0.32, blue: 0.27), category: .other, stage: .switchProvider)
    ]

    private static let sampleCancelledRows: [SampleRow] = [
        SampleRow(name: "Hulu", day: date(2026, 8, 14), price: 7.99, color: Color(red: 0.11, green: 0.78, blue: 0.35), category: .streaming, stage: .needsCancel),
        SampleRow(name: "EA Play", day: date(2026, 7, 2), price: 4.99, color: Color(red: 0.12, green: 0.12, blue: 0.12), category: .gaming, stage: .keep),
        SampleRow(name: "Calm", day: date(2026, 5, 19), price: 9.99, color: Color(red: 0.15, green: 0.32, blue: 0.55), category: .health, stage: .discount)
    ]

    private static func makeSamples(_ rows: [SampleRow]) -> [Subscription] {
        var orderByStage: [SubscriptionStage: Int] = [:]
        return rows.enumerated().map { index, row in
            let order = orderByStage[row.stage, default: 0]
            orderByStage[row.stage] = order + 1
            return Subscription(
                name: row.name,
                nextPaymentDate: row.day,
                price: row.price,
                color: row.color,
                frequency: row.frequency,
                category: row.category.rawValue,
                notes: row.notes,
                addedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                stage: row.stage,
                boardOrder: order,
                isTrial: row.isTrial,
                trialEndDate: row.isTrial ? row.day : nil
            )
        }
    }

    /// Returns false when a free account is already at the tracked-subscription cap.
    @discardableResult
    func addSubscription(_ sub: Subscription) -> Bool {
        guard Self.canTrackAnotherSubscription(currentCount: subscriptions.count) else { return false }
        var sub = sub
        let nextOrder = (subscriptions.filter { $0.stage == sub.stage }.map(\.boardOrder).max() ?? -1) + 1
        sub.boardOrder = nextOrder
        subscriptions.append(sub)
        applySorting()
        persist()
        syncCategoryFilterWithSubscriptions()
        return true
    }

    private static func canTrackAnotherSubscription(currentCount: Int) -> Bool {
        let raw = UserDefaults.standard.string(forKey: "subscriptionTier") ?? SubscriptionTier.free.rawValue
        let tier = SubscriptionTier(rawValue: raw) ?? .free
        if tier == .free {
            return currentCount < FreePlanLimits.subscriptionCount
        }
        return true
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

    /// Trials whose end date is today or earlier, still waiting for keep or cancel.
    func trialsNeedingDecision(on day: Date = Date()) -> [Subscription] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: day)
        return subscriptions.filter { sub in
            guard sub.isTrial, let end = sub.trialEndDate else { return false }
            return calendar.startOfDay(for: end) <= today
        }
    }

    /// Clears the trial and leaves the subscription on the list, with the next charge on or after today.
    func keepTrial(id: UUID) {
        guard let current = subscriptions.first(where: { $0.id == id }), current.isTrial else { return }
        var updated = current
        let end = updated.trialEndDate ?? updated.nextPaymentDate
        updated.isTrial = false
        updated.trialEndDate = nil
        updated.nextPaymentDate = updated.frequency.nextChargeDate(onOrAfter: Date(), anchoredTo: end)
        updateSubscription(updated)
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
