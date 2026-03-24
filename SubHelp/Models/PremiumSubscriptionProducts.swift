import Foundation
import StoreKit

enum PremiumSubscriptionProductID: String {
    case yearly = "com.subhelp.app.premium.yearly"
    case monthly = "com.subhelp.app.premium.monthly"
}

private enum SubscriptionStorageKeys {
    static let subscriptionTier = "subscriptionTier"
}

enum PremiumPurchaseResult: Equatable {
    case success
    case cancelled
    case pending
    case failed(String)
}

@MainActor
final class PremiumSubscriptionProducts: ObservableObject {
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var isPurchasing = false

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private static let allIDs: Set<String> = [
        PremiumSubscriptionProductID.yearly.rawValue,
        PremiumSubscriptionProductID.monthly.rawValue,
    ]

    private var updateListenerTask: Task<Void, Never>?

    init() {
        updateListenerTask = Task(priority: .background) {
            await Self.listenForTransactionUpdates()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func refresh() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: Self.allIDs)
            yearlyProduct = products.first { $0.id == PremiumSubscriptionProductID.yearly.rawValue }
            monthlyProduct = products.first { $0.id == PremiumSubscriptionProductID.monthly.rawValue }
            loadState = .loaded
        } catch {
            yearlyProduct = nil
            monthlyProduct = nil
            loadState = .failed
        }
    }

    /// Aligns local tier with active App Store subscriptions (call on launch / foreground / after restore).
    func syncEntitlementsFromStore() async {
        var chosenTier: SubscriptionTier = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productType == .autoRenewable else { continue }
            if transaction.revocationDate != nil { continue }
            switch transaction.productID {
            case PremiumSubscriptionProductID.yearly.rawValue:
                chosenTier = .yearly
            case PremiumSubscriptionProductID.monthly.rawValue:
                if chosenTier != .yearly { chosenTier = .monthly }
            default:
                break
            }
        }
        Self.persistTier(chosenTier)
    }

    /// StoreKit 2 purchase — presents the system payment sheet when products are available.
    func purchase(_ tier: SubscriptionTier) async -> PremiumPurchaseResult {
        guard tier == .yearly || tier == .monthly else { return .success }

        guard let product = (tier == .yearly) ? yearlyProduct : monthlyProduct else {
            return .failed(String(localized: "Subscription options couldn’t be loaded. Check your connection or try again in a moment."))
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await Self.applyVerifiedSubscriptionTransaction(transaction)
                    return .success
                case .unverified(_, let error):
                    return .failed(error.localizedDescription)
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(String(localized: "Something went wrong. Please try again."))
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Restore / sync with App Store (e.g. new device). Returns an error message on failure, or `nil` on success.
    func restorePurchases() async -> String? {
        do {
            try await AppStore.sync()
            await syncEntitlementsFromStore()
            return nil
        } catch {
            return error.localizedDescription
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

    private nonisolated static func listenForTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            await applyVerifiedSubscriptionTransactionIfNeeded(verificationResult)
        }
    }

    private nonisolated static func applyVerifiedSubscriptionTransaction(_ transaction: Transaction) async {
        await applyVerifiedSubscriptionTransactionIfNeeded(.verified(transaction))
    }

    private nonisolated static func applyVerifiedSubscriptionTransactionIfNeeded(_ verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else { return }
        guard transaction.productType == .autoRenewable else {
            await transaction.finish()
            return
        }

        if transaction.revocationDate != nil {
            await MainActor.run { persistTier(.free) }
        } else if isPremiumProductID(transaction.productID) {
            await MainActor.run { persistTier(forProductID: transaction.productID) }
        }
        await transaction.finish()
    }

    private nonisolated static func isPremiumProductID(_ id: String) -> Bool {
        id == PremiumSubscriptionProductID.yearly.rawValue || id == PremiumSubscriptionProductID.monthly.rawValue
    }

    private nonisolated static func persistTier(forProductID productID: String) {
        switch productID {
        case PremiumSubscriptionProductID.yearly.rawValue:
            persistTier(.yearly)
        case PremiumSubscriptionProductID.monthly.rawValue:
            persistTier(.monthly)
        default:
            break
        }
    }

    private nonisolated static func persistTier(_ tier: SubscriptionTier) {
        UserDefaults.standard.set(tier.rawValue, forKey: SubscriptionStorageKeys.subscriptionTier)
    }
}
