import SwiftUI

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

    init(id: UUID = UUID(), name: String, nextPaymentDate: Date, price: Decimal, color: Color, frequency: BillingFrequency = .monthly) {
        self.id = id
        self.name = name
        self.nextPaymentDate = nextPaymentDate
        self.price = price
        self.color = color
        self.frequency = frequency
    }
}
