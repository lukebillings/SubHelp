import SwiftUI

/// Gold call-to-action shown on main tabs for free users; hidden when `subscriptionTier` is not `.free`.
struct PremiumUpgradePromoBanner: View {
    var onUpgradeTap: () -> Void

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        Button(action: onUpgradeTap) {
            Text("Want to add more than 3 subscriptions? Upgrade to SubHub Premium Now.")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(Color(red: 0.2, green: 0.14, blue: 0.02))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(gold)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}
