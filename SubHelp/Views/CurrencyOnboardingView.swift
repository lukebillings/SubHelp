import SwiftUI
import UserNotifications

struct CurrencyOnboardingView: View {
    @EnvironmentObject private var premiumProducts: PremiumSubscriptionProducts
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @AppStorage("hasCompletedCurrencyOnboarding") private var hasCompletedCurrencyOnboarding = false
    @AppStorage("onboardingPrimaryGoal") private var onboardingPrimaryGoal: String = ""
    @AppStorage("subscriptionTier") private var subscriptionTierRaw = SubscriptionTier.free.rawValue
    @Binding var isPresented: Bool
    /// Called after the user finishes the walkthrough (notifications on or not now).
    var onComplete: () -> Void = {}

    /// 0 goals → 1 paywall → 2 currency → 3 notifications
    @State private var step = 0

    private let brandGold = Color(red: 0.96, green: 0.78, blue: 0.22)
    private let skipRowHeight: CGFloat = 22

    private let goalOptions: [String] = [
        "Spend less each month",
        "Avoid surprise renewals",
        "Track all subscriptions in one place",
        "Find subscriptions I forgot about",
        "Cancel subscriptions faster",
        "None of the above"
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            NavigationStack {
                Group {
                    if step == 0 {
                        benefitsStep
                    } else if step == 1 {
                        paywallStep
                    } else if step == 2 {
                        currencyStep
                    } else {
                        notificationStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if step == 1 {
                            Button("Back") {
                                SubHelpHaptics.impact(.light)
                                step = 0
                            }
                            .foregroundStyle(.black)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if step >= 2 {
                        onboardingBottomChrome
                    }
                }
            }
            .tint(.black)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Dot-style progress for post-paywall steps only (currency, notifications).
    private var onboardingProgressBar: some View {
        let pageCount = 2
        let current = max(0, step - 2)
        return HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == current ? brandGold : Color.black.opacity(0.14))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    /// Bottom layout for currency + notifications: optional Skip + primary CTA.
    private var onboardingBottomChrome: some View {
        VStack(spacing: 12) {
            onboardingProgressBar

            if step == 3 {
                Button(role: .none) {
                    SubHelpHaptics.impact(.medium)
                    UserDefaults.standard.set(false, forKey: RenewalNotificationScheduler.notificationsEnabledKey)
                    UserDefaults.standard.set(1, forKey: "notificationDaysBefore")
                    completeOnboarding()
                } label: {
                    Text("Skip")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: skipRowHeight)
                }
                .buttonStyle(.plain)
            } else {
                Text("Skip")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: skipRowHeight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }

            Button(action: primaryOnboardingBottomAction) {
                Group {
                    if step == 3 {
                        Text("Turn on notifications")
                            .font(.system(.title3, design: .default, weight: .bold))
                    } else {
                        Text("Continue")
                            .font(.system(.title3, design: .default, weight: .bold))
                    }
                }
                .foregroundStyle(.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background {
                    ZStack {
                        ShinyGoldCTABackground()
                        CTADiagonalSheen()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: ShinyGoldCTABackground.cornerRadius, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func primaryOnboardingBottomAction() {
        SubHelpHaptics.impact(.light)
        if step == 2 {
            step = 3
        } else {
            Task {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                UserDefaults.standard.set(true, forKey: RenewalNotificationScheduler.notificationsEnabledKey)
                await MainActor.run {
                    completeOnboarding()
                }
            }
        }
    }

    private func onboardingHeader(title: String, subtitle: String?) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(.title, design: .default, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(.body, design: .default, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: subtitle == nil ? 96 : 128, alignment: .top)
        .padding(.top, 4)
    }

    private var benefitsStep: some View {
        VStack(spacing: 28) {
            onboardingHeader(
                title: "What's your number 1 goal with SubHelp.",
                subtitle: nil
            )
            .padding(.top, 54)

            VStack(spacing: 10) {
                ForEach(goalOptions, id: \.self) { goal in
                    Button {
                        SubHelpHaptics.impact(.light)
                        onboardingPrimaryGoal = goal
                        step = 1
                    } label: {
                        HStack(spacing: 10) {
                            Text(goal)
                                .font(.system(.subheadline, design: .default, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.9))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.9))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    private var currencyStep: some View {
        VStack(spacing: 20) {
            onboardingHeader(
                title: "Select currency",
                subtitle: "Choose the currency SubHelp uses for subscription prices and totals. You can change this anytime in Settings."
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Currency")
                    .font(.system(.headline, design: .default, weight: .semibold))
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(CurrencyOptions.topCurrencies + CurrencyOptions.otherCurrencies, id: \.code) { currency in
                            Button {
                                SubHelpHaptics.impact(.light)
                                currencyCode = currency.code
                            } label: {
                                HStack(spacing: 10) {
                                    Text(currency.label)
                                        .font(.system(.subheadline, design: .default, weight: .medium))
                                        .foregroundStyle(.black.opacity(0.85))
                                    Spacer(minLength: 0)
                                    if currencyCode == currency.code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(currencyCode == currency.code ? Color.blue.opacity(0.12) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.horizontal, 22)
    }

    private var notificationStep: some View {
        VStack(spacing: 20) {
            onboardingHeader(
                title: "Notifications",
                subtitle: "Turn on notifications to get renewal alerts before subscriptions charge, plus other helpful updates. You can change this anytime in Settings."
            )

            Spacer(minLength: 0)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.black.opacity(0.8))
                .frame(width: 130, height: 130)
                .background(.white.opacity(0.35))
                .clipShape(Circle())

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    private var paywallStep: some View {
        PaywallView(
            hasCompletedPaywall: Binding(
                get: { false },
                set: { finished in
                    if finished { step = 2 }
                }
            ),
            selectedTier: Binding(
                get: { SubscriptionTier(rawValue: subscriptionTierRaw) ?? .free },
                set: { subscriptionTierRaw = $0.rawValue }
            ),
            onSelect: { tier in
                subscriptionTierRaw = tier.rawValue
            }
        )
        .environmentObject(premiumProducts)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: SubHelpAppStorageKey.hasCompletedOnboardingV2)
        UserDefaults.standard.set(true, forKey: "subhelp.didCompleteNotificationSetup")
        RenewalNotificationScheduler.scheduleRenewalReminders()
        hasCompletedCurrencyOnboarding = true
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPresented = false
        }
        onComplete()
    }
}

#Preview {
    CurrencyOnboardingView(isPresented: .constant(true))
        .environmentObject(PremiumSubscriptionProducts())
}
