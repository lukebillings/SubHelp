import SwiftUI

struct Subscription: Identifiable {
    let id: UUID
    let name: String
    let nextPaymentDate: Date
    let price: Decimal
    let color: Color

    init(id: UUID = UUID(), name: String, nextPaymentDate: Date, price: Decimal, color: Color) {
        self.id = id
        self.name = name
        self.nextPaymentDate = nextPaymentDate
        self.price = price
        self.color = color
    }
}
