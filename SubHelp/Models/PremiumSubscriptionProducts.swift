import Foundation
import StoreKit

enum PremiumSubscriptionProductID: String {
    case yearly = "com.subhelp.app.premium.yearly"
    case monthly = "com.subhelp.app.premium.monthly"
}

@MainActor
final class PremiumSubscriptionProducts: ObservableObject {
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var loadState: LoadState = .idle

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private static let allIDs: [String] = [
        PremiumSubscriptionProductID.yearly.rawValue,
        PremiumSubscriptionProductID.monthly.rawValue,
    ]

    func refresh() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: Set(Self.allIDs))
            yearlyProduct = products.first { $0.id == PremiumSubscriptionProductID.yearly.rawValue }
            monthlyProduct = products.first { $0.id == PremiumSubscriptionProductID.monthly.rawValue }
            loadState = .loaded
        } catch {
            yearlyProduct = nil
            monthlyProduct = nil
            loadState = .failed
        }
    }

    func yearlyPlanTitle(fallback: String = "£29.99 per year") -> String {
        planTitle(product: yearlyProduct, period: String(localized: "per year"), fallback: fallback)
    }

    func monthlyPlanTitle(fallback: String = "£9.99 per month") -> String {
        planTitle(product: monthlyProduct, period: String(localized: "per month"), fallback: fallback)
    }

    private func planTitle(product: Product?, period: String, fallback: String) -> String {
        switch loadState {
        case .idle, .loading:
            return String(localized: "Loading…")
        case .loaded, .failed:
            if let product {
                return "\(product.displayPrice) \(period)"
            }
            return fallback
        }
    }
}
