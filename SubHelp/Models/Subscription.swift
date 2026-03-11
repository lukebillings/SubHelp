import SwiftUI

enum BillingFrequency: String {
    case monthly = "Monthly"
    case yearly = "Yearly"

    var shortLabel: String {
        switch self {
        case .monthly: return "/mo"
        case .yearly: return "/yr"
        }
    }
}

struct Subscription: Identifiable {
    let id: UUID
    let name: String
    let nextPaymentDate: Date
    let price: Decimal
    let color: Color
    let frequency: BillingFrequency

    init(id: UUID = UUID(), name: String, nextPaymentDate: Date, price: Decimal, color: Color, frequency: BillingFrequency = .monthly) {
        self.id = id
        self.name = name
        self.nextPaymentDate = nextPaymentDate
        self.price = price
        self.color = color
        self.frequency = frequency
    }
}
