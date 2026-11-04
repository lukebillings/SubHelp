import SwiftUI

/// Categories from Help Find Subscriptions; used for both subscriptions and filtering.
enum SubscriptionCategory: String, CaseIterable {
    case streaming = "Streaming"
    case ai = "AI"
    case gaming = "Gaming"
    case ecommerce = "Ecommerce"
    case home = "Home"
    case cloudStorage = "Cloud & storage"
    case productivity = "Productivity"
    case health = "Health"
    case learning = "Learning"
    case other = "Other"

    static var allNames: [String] { allCases.map(\.rawValue) }

    /// Generic mark shown beside a subscription name. Uncategorised subs use `uncategorizedSymbolName`.
    var symbolName: String {
        switch self {
        case .streaming: return "play.tv"
        case .ai: return "brain"
        case .gaming: return "gamecontroller"
        case .ecommerce: return "cart"
        case .home: return "house"
        case .cloudStorage: return "externaldrive"
        case .productivity: return "briefcase"
        case .health: return "heart"
        case .learning: return "book"
        case .other: return "ellipsis.circle"
        }
    }

    static let uncategorizedSymbolName = "creditcard"

    static func symbolName(for category: String?) -> String {
        guard let category, let known = SubscriptionCategory(rawValue: category) else {
            return uncategorizedSymbolName
        }
        return known.symbolName
    }
}

enum BillingFrequency: String, CaseIterable {
    case weekly = "Weekly"
    case everyFourWeeks = "Every 4 weeks"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case semiannually = "Every 6 months"
    case yearly = "Yearly"

    var shortLabel: String {
        switch self {
        case .weekly: return "/wk"
        case .everyFourWeeks: return "/4wk"
        case .monthly: return "/mo"
        case .quarterly: return "/qtr"
        case .semiannually: return "/6mo"
        case .yearly: return "/yr"
        }
    }

    var periodPhrase: String {
        switch self {
        case .weekly: return "per week"
        case .everyFourWeeks: return "every 4 weeks"
        case .monthly: return "per month"
        case .quarterly: return "per quarter"
        case .semiannually: return "every 6 months"
        case .yearly: return "per year"
        }
    }

    /// Average amount paid in a month when `price` is charged on this cycle.
    func monthlyAmount(for price: Decimal) -> Decimal {
        switch self {
        case .weekly: return price * 52 / 12
        case .everyFourWeeks: return price * 13 / 12
        case .monthly: return price
        case .quarterly: return price / 3
        case .semiannually: return price / 6
        case .yearly: return price / 12
        }
    }

    /// Amount paid in a year when `price` is charged on this cycle.
    func yearlyAmount(for price: Decimal) -> Decimal {
        switch self {
        case .weekly: return price * 52
        case .everyFourWeeks: return price * 13
        case .monthly: return price * 12
        case .quarterly: return price * 4
        case .semiannually: return price * 2
        case .yearly: return price
        }
    }

    /// First charge on or after `day`, stepping forward from `anchor` by this cycle.
    func nextChargeDate(onOrAfter day: Date, anchoredTo anchor: Date, calendar: Calendar = .current) -> Date {
        let target = calendar.startOfDay(for: day)
        var cursor = calendar.startOfDay(for: anchor)
        var safety = 0
        while cursor < target && safety < 600 {
            guard let next = addingOneCycle(to: cursor, calendar: calendar), next > cursor else { break }
            cursor = calendar.startOfDay(for: next)
            safety += 1
        }
        return cursor
    }

    private func addingOneCycle(to date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .everyFourWeeks:
            return calendar.date(byAdding: .day, value: 28, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannually:
            return calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }

    /// Whether a charge anchored on `anchor` falls on `day`, including earlier and later cycles.
    func renews(on day: Date, anchor: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .weekly:
            return Self.daySpan(from: anchor, to: day, calendar: calendar) % 7 == 0
        case .everyFourWeeks:
            return Self.daySpan(from: anchor, to: day, calendar: calendar) % 28 == 0
        case .monthly:
            return calendar.component(.day, from: day) == calendar.component(.day, from: anchor)
        case .quarterly:
            return Self.sameDayOfMonth(day, anchor, calendar: calendar)
                && Self.monthSpan(from: anchor, to: day, calendar: calendar) % 3 == 0
        case .semiannually:
            return Self.sameDayOfMonth(day, anchor, calendar: calendar)
                && Self.monthSpan(from: anchor, to: day, calendar: calendar) % 6 == 0
        case .yearly:
            return calendar.component(.month, from: day) == calendar.component(.month, from: anchor)
                && calendar.component(.day, from: day) == calendar.component(.day, from: anchor)
        }
    }

    private static func daySpan(from anchor: Date, to day: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: anchor)
        let end = calendar.startOfDay(for: day)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private static func monthSpan(from anchor: Date, to day: Date, calendar: Calendar) -> Int {
        let anchorParts = calendar.dateComponents([.year, .month], from: anchor)
        let dayParts = calendar.dateComponents([.year, .month], from: day)
        let anchorIndex = (anchorParts.year ?? 0) * 12 + (anchorParts.month ?? 0)
        let dayIndex = (dayParts.year ?? 0) * 12 + (dayParts.month ?? 0)
        return dayIndex - anchorIndex
    }

    private static func sameDayOfMonth(_ day: Date, _ anchor: Date, calendar: Calendar) -> Bool {
        calendar.component(.day, from: day) == calendar.component(.day, from: anchor)
    }
}

/// Where a subscription sits on the board. Fixed stages; missing stored values stay in Keep.
enum SubscriptionStage: String, CaseIterable, Identifiable {
    case keep = "Keep"
    case needsCancel = "Look into cancelling"
    case switchProvider = "Find other provider"
    case discount = "Try to get cheaper"

    var id: String { rawValue }

    /// Marks offered on the subscription screen. Keep is what you get by clearing a mark.
    static var markChoices: [SubscriptionStage] {
        [.needsCancel, .switchProvider, .discount]
    }

    var symbolName: String {
        switch self {
        case .keep: return "checkmark"
        case .needsCancel: return "eye"
        case .switchProvider: return "arrow.left.arrow.right"
        case .discount: return "tag"
        }
    }

    var tint: Color {
        switch self {
        case .keep: return .blue
        case .needsCancel: return .orange
        case .switchProvider: return .indigo
        case .discount: return .teal
        }
    }
}

struct Subscription: Identifiable {
    let id: UUID
    var name: String
    var nextPaymentDate: Date
    var price: Decimal
    var color: Color
    var frequency: BillingFrequency
    var category: String?
    /// Free-form reminder, such as “look into cancelling”. Empty when the user has not written one.
    var notes: String
    /// Creation time; preserved when the user edits a subscription so “date added” order stays stable.
    var addedAt: Date
    /// Board column. Existing subscriptions default to Keep.
    var stage: SubscriptionStage
    /// Order within `stage`. Lower comes first.
    var boardOrder: Int
    /// Free until `trialEndDate`. Spend totals ignore it until the user keeps it.
    var isTrial: Bool
    /// When the free period ends and the first charge happens.
    var trialEndDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        nextPaymentDate: Date,
        price: Decimal,
        color: Color,
        frequency: BillingFrequency = .monthly,
        category: String? = nil,
        notes: String = "",
        addedAt: Date = Date(),
        stage: SubscriptionStage = .keep,
        boardOrder: Int = 0,
        isTrial: Bool = false,
        trialEndDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.nextPaymentDate = nextPaymentDate
        self.price = price
        self.color = color
        self.frequency = frequency
        self.category = category
        self.notes = notes
        self.addedAt = addedAt
        self.stage = stage
        self.boardOrder = boardOrder
        self.isTrial = isTrial
        self.trialEndDate = isTrial ? trialEndDate : nil
    }

    /// Trial end is a single day. A kept subscription uses its billing cycle.
    func fallsOn(_ day: Date, calendar: Calendar = .current) -> Bool {
        if isTrial, let trialEndDate {
            return calendar.isDate(trialEndDate, inSameDayAs: day)
        }
        return frequency.renews(on: day, anchor: nextPaymentDate, calendar: calendar)
    }
}
