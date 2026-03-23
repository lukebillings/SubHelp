import SwiftUI

// MARK: - Subscription Tier

enum SubscriptionTier: String, CaseIterable {
    case yearly = "yearly"
    case monthly = "monthly"
    case free = "free"
}

// MARK: - Paywall View

struct PaywallView: View {
    @Binding var hasCompletedPaywall: Bool
    @Binding var selectedTier: SubscriptionTier
    var onSelect: (SubscriptionTier) -> Void

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
                    title: "£29.99 per year",
                    subtitle: "Add more than 3 subscriptions",
                    isRecommended: true
                ) {
                    selectedTier = .yearly
                    hasCompletedPaywall = true
                    onSelect(.yearly)
                }

                planButton(
                    title: "£9.99 per month",
                    subtitle: "Add more than 3 subscriptions",
                    isRecommended: false
                ) {
                    selectedTier = .monthly
                    hasCompletedPaywall = true
                    onSelect(.monthly)
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
    }

    private func planButton(
        title: String,
        subtitle: String,
        isRecommended: Bool,
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
    }

    private func subscriptionLegalSection(includeRestoreButton: Bool = false) -> some View {
        SubscriptionLegalFooterView(includeRestoreButton: includeRestoreButton)
    }
}

// MARK: - Subscription Legal Footer (shared)

private struct SubscriptionLegalFooterView: View {
    var includeRestoreButton: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            if includeRestoreButton {
                Button("Restore Purchases") {
                    // StoreKit restore - to be implemented
                }
                .font(.system(.caption, design: .default, weight: .regular))
                .foregroundStyle(.blue)
                .padding(.bottom, 8)
            }

            Text("Payment will be charged to your Apple Account at confirmation of purchase.\n\nSubscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.\n\nCancel anytime in App Store settings.")
                .font(.system(.caption2, design: .default, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Text("·")
                Link("Terms and Conditions", destination: URL(string: "https://example.com/terms")!)
                Text("·")
                Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.system(.caption2, design: .default, weight: .regular))
        }
    }
}

// MARK: - Upgrade Paywall (shown when free user tries to add 4th sub)

struct UpgradePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelectPlan: (SubscriptionTier) -> Void

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
                        onSelectPlan(.yearly)
                        dismiss()
                    } label: {
                        HStack {
                            Text("£29.99 per year")
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

                    Button {
                        onSelectPlan(.monthly)
                        dismiss()
                    } label: {
                        HStack {
                            Text("£9.99 per month")
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Paywall") {
    PaywallView(
        hasCompletedPaywall: .constant(false),
        selectedTier: .constant(.free),
        onSelect: { _ in }
    )
}

#Preview("Upgrade Paywall") {
    UpgradePaywallView(onSelectPlan: { _ in })
}
