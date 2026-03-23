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

                Text("SubHelp")
                    .font(.system(.title, design: .default, weight: .bold))

                Text("Add unlimited subscriptions")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 48)
            .padding(.bottom, 32)

            // Plans
            VStack(spacing: 12) {
                planButton(
                    title: "£29.99 per year",
                    subtitle: "Add unlimited subscriptions",
                    isRecommended: true
                ) {
                    selectedTier = .yearly
                    hasCompletedPaywall = true
                    onSelect(.yearly)
                }

                planButton(
                    title: "£9.99 per month",
                    subtitle: "Add unlimited subscriptions",
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

            Spacer()
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
                }
                Spacer()
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
}

// MARK: - Upgrade Paywall (shown when free user tries to add 4th sub)

struct UpgradePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelectPlan: (SubscriptionTier) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("Subscription limit reached")
                        .font(.system(.title2, design: .default, weight: .bold))

                    Text("You can add up to 3 subscriptions on the free plan. Upgrade to add unlimited subscriptions.")
                        .font(.system(.body, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
                            Text("Add unlimited subscriptions")
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
                            Text("Add unlimited subscriptions")
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

                Spacer()
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
