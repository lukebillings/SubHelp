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
    @AppStorage("onboardingPrimaryGoal") private var onboardingPrimaryGoal: String = ""
    @Binding var hasCompletedPaywall: Bool
    @Binding var selectedTier: SubscriptionTier
    var onSelect: (SubscriptionTier) -> Void

    @State private var purchaseInfoMessage: String?
    @State private var selectedOffer: SubscriptionTier = .monthly
    @State private var activeBenefitIndex: Int = 0

    private let brandGold = Color(red: 0.96, green: 0.78, blue: 0.22)
    private let ctaHorizontalPadding: CGFloat = 22
    private let ctaBottomInset: CGFloat = 16
    private let skipRowHeight: CGFloat = 22

    init(
        hasCompletedPaywall: Binding<Bool>,
        selectedTier: Binding<SubscriptionTier>,
        onSelect: @escaping (SubscriptionTier) -> Void
    ) {
        self._hasCompletedPaywall = hasCompletedPaywall
        self._selectedTier = selectedTier
        self.onSelect = onSelect
        self._purchaseInfoMessage = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .vertical) {
                paywallScrollableColumn(spacing: 22)
                    .padding(.bottom, 6)
                ScrollView(showsIndicators: false) {
                    paywallScrollableColumn(spacing: 24)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(.black)
        .background(Color(.systemBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                paywallProgressBar
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: skipRowHeight)
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
        .overlay(alignment: .topTrailing) {
#if DEBUG
            Button {
                SubHelpHaptics.impact(.light)
                hasCompletedPaywall = true
                selectedTier = .free
                onSelect(.free)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.9), in: Circle())
            }
            .padding(.top, 10)
            .padding(.trailing, 14)
#endif
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
            selectedOffer = .monthly
            await premiumProducts.refresh()
        }
        .onReceive(Timer.publish(every: 2.1, on: .main, in: .common).autoconnect()) { _ in
            guard rotatingBenefits.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                activeBenefitIndex = (activeBenefitIndex + 1) % rotatingBenefits.count
            }
        }
    }

    private var ctaButtonTitle: String {
        String(localized: "Continue")
    }

    private var rotatingBenefits: [String] {
        var benefits: [String] = []
        let trimmedPrimary = onboardingPrimaryGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrimary.isEmpty {
            benefits.append(trimmedPrimary)
        }
        let defaults = [
            String(localized: "Track unlimited subscriptions"),
            String(localized: "Subscription renewal reminders"),
            String(localized: "No ads")
        ]
        for value in defaults where !benefits.contains(value) {
            benefits.append(value)
        }
        return benefits
    }

    private func yearlyMonthlyEquivalentSubtitle() -> String? {
        guard let yearly = premiumProducts.yearlyProduct else { return nil }
        let monthlyEquivalent = yearly.price / Decimal(12)
        let formatted = monthlyEquivalent.formatted(
            yearly.priceFormatStyle
                .locale(.autoupdatingCurrent)
                .presentation(.narrow)
        )
        return String(format: String(localized: "~%@ per month"), formatted as CVarArg)
    }

    private func yearlySavingsTag() -> String? {
        guard let yearly = premiumProducts.yearlyProduct,
              let monthly = premiumProducts.monthlyProduct else { return nil }
        let yearlyAtMonthlyRate = monthly.price * Decimal(12)
        guard yearlyAtMonthlyRate > 0, yearlyAtMonthlyRate > yearly.price else { return nil }
        let savingsRatio = (yearlyAtMonthlyRate - yearly.price) / yearlyAtMonthlyRate
        let savingsPercentDecimal = NSDecimalNumber(decimal: savingsRatio * Decimal(100))
            .rounding(accordingToBehavior: nil)
        let savingsPercent = savingsPercentDecimal.intValue
        guard savingsPercent > 0 else { return nil }
        return String(format: String(localized: "SAVE ~%d%% vs monthly"), savingsPercent)
    }

    private var paywallProgressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == 3 ? brandGold : Color.black.opacity(0.14))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func paywallScrollableColumn(spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            Text("Take control of your subscriptions")
                .font(.system(.title, design: .default, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                benefitRow(
                    rotatingBenefits[min(activeBenefitIndex, rotatingBenefits.count - 1)],
                    iconName: "sparkles",
                    compact: false
                )
                .id("benefit-\(activeBenefitIndex)")
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            .frame(minHeight: 28, alignment: .leading)
            .padding(16)
            .background {
                PaywallGlassPanel(cornerRadius: 20, borderEmphasized: false)
            }
            .animation(.easeInOut(duration: 0.25), value: activeBenefitIndex)

            VStack(spacing: 12) {
                selectablePlanButton(
                    title: String(localized: "Monthly"),
                    price: premiumProducts.monthlyPlanTitle(),
                    subtitle: nil,
                    goldTag: nil,
                    tier: .monthly,
                    emphasized: false,
                    compact: false
                )

                selectablePlanButton(
                    title: String(localized: "Yearly"),
                    price: premiumProducts.yearlyPlanTitle(),
                    subtitle: yearlyMonthlyEquivalentSubtitle(),
                    goldTag: yearlySavingsTag(),
                    tier: .yearly,
                    emphasized: true,
                    compact: false
                )
                .padding(.top, 14)
            }

            VStack(spacing: 6) {
                subscriptionLegalSection(includeRestoreButton: true, includePolicyLinks: false, compact: false)
                    .foregroundStyle(.black.opacity(0.85))
                SubscriptionPolicyLinksRow()
            }
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, ctaHorizontalPadding)
        .padding(.top, -30)
    }

    private func benefitRow(_ text: String, iconName: String = "checkmark.circle.fill", compact: Bool = false) -> some View {
        HStack(alignment: .center, spacing: compact ? 6 : 10) {
            Image(systemName: iconName)
                .font(compact ? .callout : .title3)
                .foregroundStyle(brandGold)
            Text(text)
                .font(.system(compact ? .caption : .body, design: .default, weight: .semibold))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.9)
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
        // Monthly plan price (regular weight; yearly card no longer shows this price).
        let priceFont: Font = {
            if compact {
                return .system(.callout, design: .default, weight: .regular)
            }
            return .system(.subheadline, design: .default, weight: .regular)
        }()
        // Same text style size as `priceFont`, regular weight (yearly renewal line only).
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
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            Spacer(minLength: 0)
                            VStack(alignment: .trailing, spacing: compact ? 2 : 4) {
                                Text(price)
                                    .font(priceFont)
                                    .foregroundStyle(.black)
                                    .multilineTextAlignment(.trailing)
                                    .layoutPriority(1)
                                Text(yearlySubtitle)
                                    .font(yearlyRenewalFont)
                                    .foregroundStyle(.black.opacity(0.78))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                    .multilineTextAlignment(.trailing)
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
                                    .foregroundStyle(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                if let goldTag, !goldTag.isEmpty {
                                    Text(goldTag)
                                        .font(.system(compact ? .caption2 : .caption, design: .default, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.88))
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
                                    .foregroundStyle(.black.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(price)
                            .font(priceFont)
                            .foregroundStyle(.black)
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
        .disabled(premiumProducts.isPurchasing)
    }

    private func subscriptionLegalSection(includeRestoreButton: Bool = false, includePolicyLinks: Bool = true, compact: Bool = false) -> some View {
        SubscriptionLegalFooterView(includeRestoreButton: includeRestoreButton, includePolicyLinks: includePolicyLinks, compact: compact)
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
        .foregroundStyle(.black.opacity(0.7))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subscription Legal Footer (shared)

private struct SubscriptionLegalFooterView: View {
    @EnvironmentObject private var premiumProducts: PremiumSubscriptionProducts
    var includeRestoreButton: Bool = false
    var includePolicyLinks: Bool = true
    var compact: Bool = false
    @State private var restoreAlertMessage: String?
    private let legalFont: Font = .system(.caption2, design: .default, weight: .regular)
    private let legalTextColor = Color.black.opacity(0.7)

    private var subscriptionDisclosureText: String {
        if compact {
            "Cancel anytime in App Store settings.\nPayment will be charged to your Apple Account at confirmation of purchase.\nSubscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period."
        } else {
            "Cancel anytime in App Store settings.\n\nPayment will be charged to your Apple Account at confirmation of purchase.\n\nSubscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period."
        }
    }

    var body: some View {
        VStack(spacing: compact ? 6 : 16) {
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
                .padding(.bottom, compact ? 2 : 8)
            }

            Text(subscriptionDisclosureText)
                .font(legalFont)
                .foregroundStyle(legalTextColor)
                .multilineTextAlignment(.center)

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

                    Text("Subscribe to SubHelp Premium to add more than 3 subscriptions.")
                        .font(.system(.body, design: .default, weight: .regular))
                        .foregroundStyle(.black.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .padding(32)

                VStack(spacing: 12) {
                    Button {
                        SubHelpHaptics.impact(.light)
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
                        SubHelpHaptics.impact(.light)
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
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .tint(.black)
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

// MARK: - Paywall glass surfaces (match onboarding on brand blue)

struct PaywallGlassPanel: View {
    var cornerRadius: CGFloat = 20
    var borderEmphasized: Bool = false
    private let brandGold = Color(red: 0.96, green: 0.78, blue: 0.22)

    var body: some View {
        let r = cornerRadius
        ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(Color.white.opacity(borderEmphasized ? 0.26 : 0.16))
        }
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
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
