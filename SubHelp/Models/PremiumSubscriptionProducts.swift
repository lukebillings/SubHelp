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
        let tier = await Self.currentPremiumTier()
        Self.persistTier(tier)
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

    func yearlyPlanTitle(fallback: String? = nil) -> String {
        let fb = fallback ?? String(localized: "Price unavailable")
        return planTitle(product: yearlyProduct, period: String(localized: "per year"), fallback: fb)
    }

    func monthlyPlanTitle(fallback: String? = nil) -> String {
        let fb = fallback ?? String(localized: "Price unavailable")
        return planTitle(product: monthlyProduct, period: String(localized: "per month"), fallback: fb)
    }

    private static func formattedStoreAmount(_ amount: Decimal, product: Product) -> String {
        amount.formatted(
            product.priceFormatStyle
                .locale(.autoupdatingCurrent)
                .presentation(.narrow)
        )
    }

    private func planTitle(product: Product?, period: String, fallback: String) -> String {
        switch loadState {
        case .idle, .loading:
            return String(localized: "Loading…")
        case .loaded, .failed:
            if let product {
                return "\(Self.formattedStoreAmount(product.price, product: product)) \(period)"
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
        let shouldRefreshTier = transaction.productType == .autoRenewable && isPremiumProductID(transaction.productID)
        await transaction.finish()
        // Grant from current entitlements only. A finished or expired transaction must not unlock Premium by itself.
        guard shouldRefreshTier else { return }
        let tier = await currentPremiumTier()
        await MainActor.run { persistTier(tier) }
    }

    /// Yearly wins over monthly. Revoked and expired subscriptions stay on the free plan.
    private nonisolated static func currentPremiumTier() async -> SubscriptionTier {
        var chosenTier: SubscriptionTier = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard let tier = premiumTier(for: transaction) else { continue }
            if tier == .yearly { return .yearly }
            chosenTier = .monthly
        }
        return chosenTier
    }

    private nonisolated static func premiumTier(for transaction: Transaction) -> SubscriptionTier? {
        guard transaction.productType == .autoRenewable else { return nil }
        guard isPremiumProductID(transaction.productID) else { return nil }
        guard transaction.revocationDate == nil else { return nil }
        if let expiration = transaction.expirationDate, expiration <= Date() { return nil }
        switch transaction.productID {
        case PremiumSubscriptionProductID.yearly.rawValue:
            return .yearly
        case PremiumSubscriptionProductID.monthly.rawValue:
            return .monthly
        default:
            return nil
        }
    }

    private nonisolated static func isPremiumProductID(_ id: String) -> Bool {
        id == PremiumSubscriptionProductID.yearly.rawValue || id == PremiumSubscriptionProductID.monthly.rawValue
    }

    private nonisolated static func persistTier(_ tier: SubscriptionTier) {
        UserDefaults.standard.set(tier.rawValue, forKey: SubscriptionStorageKeys.subscriptionTier)
    }
}
