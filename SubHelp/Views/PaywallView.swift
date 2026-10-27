import SwiftUI
import StoreKit

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
    /// Onboarding uses the step dots. The add-subscription paywall does not.
    var showsOnboardingProgress: Bool = true
    /// Lets someone stay on the free plan with their first subscription.
    var allowsDismiss: Bool = false

    @State private var purchaseInfoMessage: String?
    @State private var selectedOffer: SubscriptionTier = .yearly

    private let brandGold = Color(red: 0.96, green: 0.78, blue: 0.22)
    private let ctaHorizontalPadding: CGFloat = 22
    private let ctaBottomInset: CGFloat = 16
    private let skipRowHeight: CGFloat = 22

    init(
        hasCompletedPaywall: Binding<Bool>,
        selectedTier: Binding<SubscriptionTier>,
        showsOnboardingProgress: Bool = true,
        allowsDismiss: Bool = false,
        onSelect: @escaping (SubscriptionTier) -> Void
    ) {
        self._hasCompletedPaywall = hasCompletedPaywall
        self._selectedTier = selectedTier
        self.showsOnboardingProgress = showsOnboardingProgress
        self.allowsDismiss = allowsDismiss
        self.onSelect = onSelect
        self._purchaseInfoMessage = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                paywallOffers
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 4) {
                subscriptionLegalSection(includeRestoreButton: true, includePolicyLinks: false)
                SubscriptionPolicyLinksRow()
            }
            .padding(.horizontal, ctaHorizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(.primary)
        .background { SubHelpBackdrop() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                if showsOnboardingProgress {
                    paywallProgressBar
                }
                if allowsDismiss {
                    Button("Not now") {
                        hasCompletedPaywall = true
                    }
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: skipRowHeight)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: skipRowHeight)
                }
                Text(ctaCaption)
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Button {
                    SubHelpHaptics.impact(.medium)
                    Task { await purchasePremium(tier: selectedOffer) }
                } label: {
                    Text(ctaButtonTitle)
                        .font(.system(.title3, design: .default, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background {
                            ZStack {
                                ShinyGoldCTABackground()
                                if !premiumProducts.isPurchasing {
                                    CTADiagonalSheen()
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: ShinyGoldCTABackground.cornerRadius, style: .continuous))
                        }
                }
                .buttonStyle(.plain)
                .disabled(premiumProducts.isPurchasing)
            }
            .padding(.horizontal, ctaHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, ctaBottomInset)
        }
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

    private var ctaButtonTitle: String {
        switch selectedOffer {
        case .yearly:
            return String(localized: "Continue with yearly")
        case .monthly:
            return String(localized: "Continue with monthly")
        case .free:
            return String(localized: "Continue")
        }
    }

    /// Sits on the purchase button so the App Store sheet matches what they just read.
    private var ctaCaption: String {
        switch selectedOffer {
        case .yearly:
            if let amount = PaywallPricing.narrowAmount(premiumProducts.yearlyProduct) {
                return String(format: String(localized: "%@ per year · cancel anytime"), amount as CVarArg)
            }
            return String(localized: "Billed annually · cancel anytime")
        case .monthly:
            return String(localized: "Billed monthly · cancel anytime")
        case .free:
            return String(localized: "Cancel anytime")
        }
    }

    /// Features the app actually offers. Goals such as spending less are not promised here.
    private var paywallFeatures: [(icon: String, text: String)] {
        [
            ("infinity", String(localized: "Track unlimited subscriptions")),
            ("bell.badge", String(localized: "Subscription renewal reminders")),
            ("apps.iphone", String(localized: "Upcoming payments widget"))
        ]
    }

    /// Unit price of the yearly plan. The amount charged is the yearly price on the card.
    private func yearlyPerMonthPrice() -> String? {
        guard let yearly = premiumProducts.yearlyProduct else { return nil }
        let formatted = PaywallPricing.narrow(yearly.price / Decimal(12), product: yearly)
        return String(format: String(localized: "~%@/mo"), formatted as CVarArg)
    }

    private func yearlySavingsTag() -> String {
        if let percent = PaywallPricing.savingsPercent(
            yearly: premiumProducts.yearlyProduct,
            monthly: premiumProducts.monthlyProduct
        ) {
            return String(format: String(localized: "SAVE %d%% vs Monthly"), percent)
        }
        return String(localized: "BEST VALUE")
    }

    private var paywallProgressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == 3 ? brandGold : Color.primary.opacity(0.14))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
    }

    private var paywallOffers: some View {
        VStack(spacing: 18) {
            Text("Take control of your subscriptions")
                .font(.system(.title, design: .default, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(paywallFeatures.enumerated()), id: \.offset) { _, feature in
                    benefitRow(feature.text, iconName: feature.icon, compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background {
                PaywallGlassPanel(cornerRadius: 20, borderEmphasized: false)
            }

            Text("SubHelp Premium")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                selectablePlanButton(
                    title: String(localized: "Yearly"),
                    price: premiumProducts.yearlyPlanTitle(),
                    subtitle: yearlyPerMonthPrice(),
                    goldTag: yearlySavingsTag(),
                    tier: .yearly,
                    emphasized: true,
                    compact: false
                )
                .padding(.top, 14)

                selectablePlanButton(
                    title: String(localized: "Monthly"),
                    price: premiumProducts.monthlyPlanTitle(),
                    subtitle: nil,
                    goldTag: nil,
                    tier: .monthly,
                    emphasized: false,
                    compact: false
                )
            }
        }
        .padding(.horizontal, ctaHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func benefitRow(_ text: String, iconName: String = "checkmark.circle.fill", compact: Bool = false) -> some View {
        HStack(alignment: .center, spacing: compact ? 6 : 10) {
            Image(systemName: iconName)
                .font(compact ? .callout : .body)
                .foregroundStyle(brandGold)
                .frame(width: compact ? 18 : 24, alignment: .center)
            Text(text)
                .font(.system(compact ? .caption : .subheadline, design: .default, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
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

    private func selectablePlanButton(
        title: String,
        price: String,
        subtitle: String?,
        goldTag: String? = nil,
        tier: SubscriptionTier,
        emphasized: Bool,
        compact: Bool = false
    ) -> some View {
        let selected = selectedOffer == tier
        let titleFont: Font = {
            if compact {
                return .system(.title3, design: .default, weight: .bold)
            }
            return .system(.title2, design: .default, weight: .bold)
        }()
        let yearlyRenewalFont: Font = {
            if compact {
                return .system(.callout, design: .default, weight: .regular)
            }
            return .system(.subheadline, design: .default, weight: .regular)
        }()
        let cardPadding: CGFloat = compact ? (emphasized ? 12 : 10) : (emphasized ? 18 : 16)
        let corner: CGFloat = compact ? 14 : 20
        return Button {
            SubHelpHaptics.impact(.light)
            selectedOffer = tier
        } label: {
            Group {
                if tier == .yearly {
                    let yearlySubtitle = subtitle ?? ""
                    VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                        HStack(alignment: .center, spacing: 10) {
                            Text(title)
                                .font(titleFont)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            Spacer(minLength: 0)
                            VStack(alignment: .trailing, spacing: compact ? 2 : 4) {
                                Text(price)
                                    .font(compact ? .system(.headline, design: .default, weight: .bold) : .system(.headline, design: .default, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                                Text(yearlySubtitle)
                                    .font(yearlyRenewalFont)
                                    .foregroundStyle(.primary.opacity(0.78))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                    .opacity(yearlySubtitle.isEmpty ? 0 : 1)
                            }
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                            HStack(alignment: .center, spacing: 8) {
                                Text(title)
                                    .font(titleFont)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                if let goldTag, !goldTag.isEmpty {
                                    Text(goldTag)
                                        .font(.system(compact ? .caption2 : .caption, design: .default, weight: .bold))
                                        .foregroundStyle(.primary.opacity(0.88))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, compact ? 3 : 4)
                                        .background {
                                            Capsule(style: .continuous)
                                                .fill(brandGold.opacity(0.42))
                                        }
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .strokeBorder(brandGold.opacity(0.95), lineWidth: 1)
                                        }
                                }
                            }
                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(compact ? .caption2 : .caption, design: .default, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(price)
                            .font(compact ? .system(.headline, design: .default, weight: .bold) : .system(.headline, design: .default, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                            .layoutPriority(1)
                    }
                }
            }
            .padding(cardPadding)
            .background {
                if compact {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.white.opacity(selected ? 0.22 : 0.12))
                } else {
                    PaywallGlassPanel(cornerRadius: corner, borderEmphasized: selected)
                }
            }
            .overlay(alignment: .top) {
                if tier == .yearly, let goldTag, !goldTag.isEmpty {
                    Text(goldTag)
                        .font(.system(compact ? .caption2 : .caption2, design: .default, weight: .bold))
                        .foregroundStyle(.black.opacity(0.88))
                        .padding(.horizontal, 10)
                        .padding(.vertical, compact ? 3 : 4)
                        .background {
                            Capsule(style: .continuous)
                                .fill(brandGold)
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(brandGold.opacity(0.95), lineWidth: 1)
                        }
                        .offset(y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(selected ? 1.0 : 0.985)
        .animation(SubHelpTheme.bouncy, value: selectedOffer)
        .disabled(premiumProducts.isPurchasing)
    }

    private func subscriptionLegalSection(includeRestoreButton: Bool = false, includePolicyLinks: Bool = true) -> some View {
        SubscriptionLegalFooterView(includeRestoreButton: includeRestoreButton, includePolicyLinks: includePolicyLinks)
    }
}

// MARK: - Policy links (shared row)

private struct SubscriptionPolicyLinksRow: View {
    var body: some View {
        HStack(spacing: 4) {
            Link("Privacy Policy", destination: URL(string: "https://lukebillings.github.io/SubHelp/privacypolicy/index.html")!)
            Text("·")
            Link("Terms and Conditions", destination: URL(string: "https://lukebillings.github.io/SubHelp/termsandconditions/index.html")!)
            Text("·")
            Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
        .font(.system(.caption2, design: .default, weight: .regular))
        .foregroundStyle(.primary.opacity(0.7))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subscription Legal Footer (shared)

private struct SubscriptionLegalFooterView: View {
    @EnvironmentObject private var premiumProducts: PremiumSubscriptionProducts
    var includeRestoreButton: Bool = false
    var includePolicyLinks: Bool = true
    @State private var restoreAlertMessage: String?
    private let legalFont: Font = .system(.caption2, design: .default, weight: .regular)
    private let legalTextColor = Color.primary.opacity(0.7)

    private var subscriptionDisclosureText: String {
        "Payment is charged to your Apple Account at confirmation of purchase. The subscription renews automatically unless you cancel at least 24 hours before the period ends in Apple Account settings, and your account is charged for renewal within those 24 hours."
    }

    var body: some View {
        VStack(spacing: 4) {
            if includeRestoreButton {
                Button("Restore Purchases") {
                    SubHelpHaptics.impact(.light)
                    Task {
                        if let error = await premiumProducts.restorePurchases() {
                            restoreAlertMessage = error
                        } else {
                            restoreAlertMessage = String(localized: "Your purchases were synced with the App Store.")
                        }
                    }
                }
                .font(legalFont)
                .foregroundStyle(legalTextColor)
                .disabled(premiumProducts.isPurchasing)
            }

            Text(subscriptionDisclosureText)
                .font(legalFont)
                .foregroundStyle(legalTextColor)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            if includePolicyLinks {
                SubscriptionPolicyLinksRow()
            }
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

                    Text("Subscribe to SubHelp Premium to add a second subscription.")
                        .font(.system(.body, design: .default, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .padding(32)

                VStack(spacing: 14) {
                    Button {
                        SubHelpHaptics.impact(.medium)
                        Task { await purchasePlan(.yearly) }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Yearly")
                                    .font(.system(.title3, design: .default, weight: .bold))
                                Spacer(minLength: 8)
                                yearlyUpgradePrice
                            }
                            Text(yearlyUpgradeSubtitle)
                                .font(.system(.subheadline, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            PaywallGlassPanel(cornerRadius: 24, borderEmphasized: true)
                        }
                        .overlay(alignment: .top) {
                            Text(yearlyUpgradeBadge)
                                .font(.system(.caption2, design: .default, weight: .bold))
                                .foregroundStyle(.black.opacity(0.88))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(Color(red: 0.96, green: 0.78, blue: 0.22))
                                }
                                .offset(y: -10)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(premiumProducts.isPurchasing)

                    Button {
                        SubHelpHaptics.impact(.light)
                        Task { await purchasePlan(.monthly) }
                    } label: {
                        Text(monthlyUpgradeTitle)
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(premiumProducts.isPurchasing)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer(minLength: 0)

                SubscriptionLegalFooterView(includeRestoreButton: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                Spacer(minLength: 16)
            }
            .background { SubHelpBackdrop() }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
            .overlay {
                if premiumProducts.isPurchasing {
                    Color.black.opacity(0.12)
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
    }

    private var yearlyUpgradeBadge: String {
        if let percent = PaywallPricing.savingsPercent(
            yearly: premiumProducts.yearlyProduct,
            monthly: premiumProducts.monthlyProduct
        ) {
            return String(format: String(localized: "SAVE %d%% vs Monthly"), percent)
        }
        return String(localized: "BEST VALUE")
    }

    private var yearlyUpgradePrice: some View {
        let hero: String = {
            guard let yearly = premiumProducts.yearlyProduct else {
                return premiumProducts.yearlyPlanTitle()
            }
            let formatted = PaywallPricing.narrow(yearly.price / Decimal(12), product: yearly)
            return String(format: String(localized: "~%@/mo"), formatted as CVarArg)
        }()
        return Text(hero)
            .font(.system(.title3, design: .default, weight: .bold))
    }

    private var yearlyUpgradeSubtitle: String {
        if let amount = PaywallPricing.narrowAmount(premiumProducts.yearlyProduct) {
            return String(format: String(localized: "Billed %@ per year · cancel anytime"), amount as CVarArg)
        }
        return String(localized: "Billed annually · cancel anytime")
    }

    private var monthlyUpgradeTitle: String {
        let price = premiumProducts.monthlyPlanTitle()
        return String(format: String(localized: "Or %@"), price as CVarArg)
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

// MARK: - Plan price framing

private enum PaywallPricing {
    static func narrow(_ amount: Decimal, product: Product) -> String {
        amount.formatted(
            product.priceFormatStyle
                .locale(.autoupdatingCurrent)
                .presentation(.narrow)
        )
    }

    static func narrowAmount(_ product: Product?) -> String? {
        guard let product else { return nil }
        return narrow(product.price, product: product)
    }

    static func savingsPercent(yearly: Product?, monthly: Product?) -> Int? {
        guard let yearly, let monthly else { return nil }
        let yearlyAtMonthlyRate = monthly.price * Decimal(12)
        guard yearlyAtMonthlyRate > 0, yearlyAtMonthlyRate > yearly.price else { return nil }
        let savingsRatio = (yearlyAtMonthlyRate - yearly.price) / yearlyAtMonthlyRate
        let savingsPercent = NSDecimalNumber(decimal: savingsRatio * Decimal(100))
            .rounding(accordingToBehavior: nil)
            .intValue
        return savingsPercent > 0 ? savingsPercent : nil
    }
}

// MARK: - Paywall glass surfaces (match onboarding on brand blue)

struct PaywallGlassPanel: View {
    var cornerRadius: CGFloat = 20
    var borderEmphasized: Bool = false
    private let brandGold = Color(red: 0.96, green: 0.78, blue: 0.22)

    var body: some View {
        let r = cornerRadius
        surface(r)
        .overlay {
            if borderEmphasized {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(brandGold, lineWidth: 2.5)
            } else {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.58),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
        }
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private func surface(_ r: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(borderEmphasized ? brandGold.opacity(0.16) : nil), in: shape)
        } else {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color.white.opacity(borderEmphasized ? 0.26 : 0.16))
            }
            .clipShape(shape)
        }
    }
}

// MARK: - Paywall CTA diagonal sheen

/// Animated diagonal highlight sweep across the gold CTA (paywall only).
struct CTADiagonalSheen: View {
    private let cornerRadius = ShinyGoldCTABackground.cornerRadius
    private let sweepPeriod: Double = 2.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let t = context.date.timeIntervalSinceReferenceDate / sweepPeriod
                let phase = CGFloat(t - floor(t))

                let bandWidth = max(80, h * 1.15)
                let travel = w + bandWidth * 1.5
                let xShift = -travel * 0.48 + phase * travel

                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0), location: 0),
                                .init(color: .white.opacity(0.18), location: 0.38),
                                .init(color: .white.opacity(0.62), location: 0.5),
                                .init(color: .white.opacity(0.18), location: 0.62),
                                .init(color: .white.opacity(0), location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: bandWidth, height: h * 3)
                    .rotationEffect(.degrees(-50))
                    .offset(x: xShift)
                    .blendMode(.screen)
                    .frame(width: w, height: h)
                    .clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - Shiny gold primary CTA

/// Solid metallic gold with a bright highlight (Continue, Turn on notifications, etc.).
struct ShinyGoldCTABackground: View {
    static let cornerRadius: CGFloat = 24

    var body: some View {
        let r = Self.cornerRadius
        RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(Self.metallicGoldGradient)
            .overlay {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: UnitPoint(x: 0.55, y: 0.5)
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.65),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            .shadow(color: Color(red: 0.96, green: 0.78, blue: 0.22).opacity(0.42), radius: 14, x: 0, y: 7)
    }

    private static var metallicGoldGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 1.0, green: 0.93, blue: 0.48), location: 0),
                .init(color: Color(red: 0.99, green: 0.84, blue: 0.32), location: 0.38),
                .init(color: Color(red: 0.96, green: 0.72, blue: 0.16), location: 0.72),
                .init(color: Color(red: 0.82, green: 0.56, blue: 0.06), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
