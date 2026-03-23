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

struct Subscription: Identifiable {
    let id: UUID
    var name: String
    var nextPaymentDate: Date
    var price: Decimal
    var color: Color
    var frequency: BillingFrequency
    var category: String?

    init(id: UUID = UUID(), name: String, nextPaymentDate: Date, price: Decimal, color: Color, frequency: BillingFrequency = .monthly, category: String? = nil) {
        self.id = id
        self.name = name
        self.nextPaymentDate = nextPaymentDate
        self.price = price
        self.color = color
        self.frequency = frequency
        self.category = category
    }
}
