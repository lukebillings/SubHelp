import SwiftUI

// MARK: - Subscription Tier

enum SubscriptionTier: String, CaseIterable {
    case yearly = "yearly"
    case monthly = "monthly"
    case free = "free"
}

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject private var premiumProducts: PremiumSubscriptionProducts
    @Binding var hasCompletedPaywall: Bool
    @Binding var selectedTier: SubscriptionTier
    var onSelect: (SubscriptionTier) -> Void

    @State private var purchaseInfoMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("ShibaMascot")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                Text("SubHelp Premium")
                    .font(.system(.title, design: .default, weight: .bold))

                VStack(spacing: 4) {
                    Text("Want to add all your subscriptions? With a small subscription you can do just that!")
                        .font(.system(.subheadline, design: .default, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                    Text("Add more than 3 subscriptions")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 48)
            .padding(.bottom, 32)

            // Plans
            VStack(spacing: 12) {
                planButton(
                    title: premiumProducts.yearlyPlanTitle(),
                    subtitle: "Add more than 3 subscriptions",
                    isRecommended: true,
                    disabled: premiumProducts.isPurchasing
                ) {
                    Task { await purchasePremium(tier: .yearly) }
                }

                planButton(
                    title: premiumProducts.monthlyPlanTitle(),
                    subtitle: "Add more than 3 subscriptions",
                    isRecommended: false,
                    disabled: premiumProducts.isPurchasing
                ) {
                    Task { await purchasePremium(tier: .monthly) }
                }

                Button {
                    selectedTier = .free
                    hasCompletedPaywall = true
                    onSelect(.free)
                } label: {
                    Text("Maybe later")
                        .font(.system(.body, design: .default, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            subscriptionLegalSection(includeRestoreButton: true)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if premiumProducts.isPurchasing {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .alert("SubHelp Premium", isPresented: Binding(
            get: { purchaseInfoMessage != nil },
            set: { if !$0 { purchaseInfoMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseInfoMessage ?? "")
        }
        .task {
            await premiumProducts.refresh()
        }
    }

    private func purchasePremium(tier: SubscriptionTier) async {
        let result = await premiumProducts.purchase(tier)
        switch result {
        case .success:
            selectedTier = tier
            hasCompletedPaywall = true
            onSelect(tier)
        case .cancelled:
            break
        case .pending:
            purchaseInfoMessage = String(localized: "Your purchase is waiting for approval. SubHelp Premium will unlock when it completes.")
        case .failed(let message):
            purchaseInfoMessage = message
        }
    }

    private func planButton(
        title: String,
        subtitle: String,
        isRecommended: Bool,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(.headline, design: .default, weight: .semibold))
                        if isRecommended {
                            Text("Best value")
                                .font(.system(.caption2, design: .default, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isRecommended ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func subscriptionLegalSection(includeRestoreButton: Bool = false) -> some View {
        SubscriptionLegalFooterView(includeRestoreButton: includeRestoreButton)
    }
}

// MARK: - Subscription Legal Footer (shared)

private struct SubscriptionLegalFooterView: View {
    @EnvironmentObject private var premiumProducts: PremiumSubscriptionProducts
    var includeRestoreButton: Bool = false
    @State private var restoreAlertMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if includeRestoreButton {
                Button("Restore Purchases") {
                    Task {
                        if let error = await premiumProducts.restorePurchases() {
                            restoreAlertMessage = error
                        } else {
                            restoreAlertMessage = String(localized: "Your purchases were synced with the App Store.")
                        }
                    }
                }
                .font(.system(.caption, design: .default, weight: .regular))
                .foregroundStyle(.blue)
                .disabled(premiumProducts.isPurchasing)
                .padding(.bottom, 8)
            }

            Text("Payment will be charged to your Apple Account at confirmation of purchase.\n\nSubscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.\n\nCancel anytime in App Store settings.")
                .font(.system(.caption2, design: .default, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Link("Privacy Policy", destination: URL(string: "https://lukebillings.github.io/SubHelp/privacypolicy/index.html")!)
                Text("·")
                Link("Terms and Conditions", destination: URL(string: "https://lukebillings.github.io/SubHelp/termsandconditions/index.html")!)
                Text("·")
                Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.system(.caption2, design: .default, weight: .regular))
        }
        .alert("Restore", isPresented: Binding(
            get: { restoreAlertMessage != nil },
            set: { if !$0 { restoreAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreAlertMessage ?? "")
        }
    }
}

// MARK: - Upgrade Paywall (shown when free user tries to add 4th sub)

struct UpgradePaywallView: View {
    @EnvironmentObject private var premiumProducts: PremiumSubscriptionProducts
    @Environment(\.dismiss) private var dismiss
    var onSelectPlan: (SubscriptionTier) -> Void

    @State private var purchaseInfoMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image("ShibaMascot")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                    Text("Subscription limit reached")
                        .font(.system(.title2, design: .default, weight: .bold))

                    Text("Subscribe to SubHelp Premium to add more than 3 subscriptions.")
                        .font(.system(.body, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .padding(32)

                VStack(spacing: 12) {
                    Button {
                        Task { await purchasePlan(.yearly) }
                    } label: {
                        HStack {
                            Text(premiumProducts.yearlyPlanTitle())
                                .font(.system(.headline, design: .default, weight: .semibold))
                            Spacer()
                            Text("Add more than 3 subscriptions")
                                .font(.system(.subheadline, design: .default, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(premiumProducts.isPurchasing)

                    Button {
                        Task { await purchasePlan(.monthly) }
                    } label: {
                        HStack {
                            Text(premiumProducts.monthlyPlanTitle())
                                .font(.system(.headline, design: .default, weight: .semibold))
                            Spacer()
                            Text("Add more than 3 subscriptions")
                                .font(.system(.subheadline, design: .default, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(premiumProducts.isPurchasing)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                SubscriptionLegalFooterView(includeRestoreButton: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                Spacer(minLength: 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if premiumProducts.isPurchasing {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") {
                        dismiss()
                    }
                    .disabled(premiumProducts.isPurchasing)
                }
            }
            .alert("SubHelp Premium", isPresented: Binding(
                get: { purchaseInfoMessage != nil },
                set: { if !$0 { purchaseInfoMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseInfoMessage ?? "")
            }
            .task {
                await premiumProducts.refresh()
            }
        }
    }

    private func purchasePlan(_ tier: SubscriptionTier) async {
        let result = await premiumProducts.purchase(tier)
        switch result {
        case .success:
            onSelectPlan(tier)
            dismiss()
        case .cancelled:
            break
        case .pending:
            purchaseInfoMessage = String(localized: "Your purchase is waiting for approval. SubHelp Premium will unlock when it completes.")
        case .failed(let message):
            purchaseInfoMessage = message
        }
    }
}

#Preview("Paywall") {
    PaywallView(
        hasCompletedPaywall: .constant(false),
        selectedTier: .constant(.free),
        onSelect: { _ in }
    )
    .environmentObject(PremiumSubscriptionProducts())
}

#Preview("Upgrade Paywall") {
    UpgradePaywallView(onSelectPlan: { _ in })
        .environmentObject(PremiumSubscriptionProducts())
}
