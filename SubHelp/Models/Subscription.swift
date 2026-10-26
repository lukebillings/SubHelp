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

    static var allNames: [String] { allCases.map(\.rawValue) }
}

enum BillingFrequency: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var shortLabel: String {
        switch self {
        case .weekly: return "/wk"
        case .monthly: return "/mo"
        case .yearly: return "/yr"
        }
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
        boardOrder: Int = 0
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
    }
}
