import SwiftUI

enum SubscriptionViewMode: String, CaseIterable {
    case list = "List"
    case calendar = "Calendar"
}

final class HomeViewModel: ObservableObject {
    @Published var subscriptions: [Subscription]
    @Published var viewMode: SubscriptionViewMode = .list
    @Published var savedAmount: Decimal = 23

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        return f
    }()

    var totalPerMonth: Decimal {
        subscriptions.reduce(0) { $0 + $1.price }
    }

    var totalPerYear: Decimal {
        totalPerMonth * 12
    }

    init(subscriptions: [Subscription]? = nil) {
        self.subscriptions = subscriptions ?? HomeViewModel.sampleSubscriptions
    }

    static var sampleSubscriptions: [Subscription] {
        let june7 = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 7)) ?? Date()
        return [
            Subscription(name: "Spotify", nextPaymentDate: june7, price: 9.99, color: Color(red: 0.11, green: 0.84, blue: 0.38)),
            Subscription(name: "Netflix", nextPaymentDate: june7, price: 9.99, color: Color(red: 0.89, green: 0.15, blue: 0.21)),
            Subscription(name: "Disney+", nextPaymentDate: june7, price: 9.99, color: Color(red: 0.0, green: 0.48, blue: 0.9)),
            Subscription(name: "Prime", nextPaymentDate: june7, price: 9.99, color: Color(red: 0.24, green: 0.6, blue: 0.87)),
            Subscription(name: "YouTube Premium", nextPaymentDate: june7, price: 12.99, color: Color(red: 0.93, green: 0.11, blue: 0.14)),
            Subscription(name: "iCloud+", nextPaymentDate: june7, price: 2.99, color: Color(red: 0.35, green: 0.78, blue: 0.98)),
            Subscription(name: "Gym", nextPaymentDate: june7, price: 29.99, color: Color(red: 0.6, green: 0.35, blue: 0.71)),
            Subscription(name: "ChatGPT Plus", nextPaymentDate: june7, price: 19.99, color: Color(red: 0.29, green: 0.65, blue: 0.55)),
            Subscription(name: "Xbox Game Pass", nextPaymentDate: june7, price: 14.99, color: Color(red: 0.07, green: 0.49, blue: 0.17))
        ]
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
