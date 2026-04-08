import SwiftUI
import UserNotifications

struct CurrencyOnboardingView: View {
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @AppStorage("hasCompletedCurrencyOnboarding") private var hasCompletedCurrencyOnboarding = false
    @Binding var isPresented: Bool
    /// Called after the user finishes the walkthrough (notifications on or not now).
    var onComplete: () -> Void = {}

    @State private var step = 0
    @State private var benefitPageIndex = 0

    private let brandGold = Color(red: 0.96, green: 0.78, blue: 0.22)

    private let benefitPages: [BenefitPage] = [
        BenefitPage(
            title: "CLARITY",
            message: "View subscriptions in one place.",
            screenshotName: "OnboardingShot1"
        ),
        BenefitPage(
            title: "AWARE",
            message: "Help find forgotten subscriptions.",
            screenshotName: "OnboardingShot3"
        ),
        BenefitPage(
            title: "READY",
            message: "Calendar view plus notifications.",
            screenshotName: "OnboardingShot4"
        ),
        BenefitPage(
            title: "RELIEF",
            message: "Help canceling your subscriptions.",
            screenshotName: "OnboardingShot2"
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            NavigationStack {
                Group {
                    if step == 0 {
                        benefitsStep
                    } else if step == 1 {
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
                        if step == 2 {
                            Button("Back") {
                                step -= 1
                            }
                            .foregroundStyle(.black)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    onboardingBottomChrome
                }
            }
            .tint(.black)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Horizontal progress under the onboarding mockup (one segment per benefit page).
    private var benefitPagesProgressBar: some View {
        let pageCount = benefitPages.count
        return GeometryReader { geo in
            let width = geo.size.width
            let fraction = CGFloat(benefitPageIndex + 1) / CGFloat(pageCount)
            Capsule()
                .fill(Color.white.opacity(0.35))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(brandGold)
                        .frame(width: width * fraction)
                }
                .clipShape(Capsule())
        }
        .frame(height: 6)
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.25), value: benefitPageIndex)
    }

    /// Same bottom layout on every step: optional “Not now” slot + primary CTA pinned to identical Y.
    private var onboardingBottomChrome: some View {
        VStack(spacing: 12) {
            if step == 2 {
                Button(role: .none) {
                    UserDefaults.standard.set(-1, forKey: "notificationDaysBefore")
                    completeOnboarding()
                } label: {
                    Text("Not now")
                        .font(.system(.headline, design: .default, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("Not now")
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundStyle(.clear)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }

            Button(action: primaryOnboardingBottomAction) {
                Group {
                    if step == 2 {
                        Label("Turn on notifications", systemImage: "bell.badge")
                            .font(.system(.title3, design: .default, weight: .bold))
                    } else {
                        Text("Continue")
                            .font(.system(.title3, design: .default, weight: .bold))
                    }
                }
                .foregroundStyle(.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background { ShinyGoldCTABackground() }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func primaryOnboardingBottomAction() {
        if step == 0 {
            if benefitPageIndex < benefitPages.count - 1 {
                benefitPageIndex += 1
            } else {
                step = 1
            }
        } else if step == 1 {
            step = 2
        } else {
            Task {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                if (UserDefaults.standard.object(forKey: "notificationDaysBefore") as? Int) == -1 {
                    UserDefaults.standard.set(1, forKey: "notificationDaysBefore")
                }
                await MainActor.run {
                    completeOnboarding()
                }
            }
        }
    }

    private var benefitsStep: some View {
        let currentPage = benefitPages[benefitPageIndex]
        return VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text(currentPage.title)
                    .font(.system(.title, design: .default, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                Text(currentPage.message)
                    .font(.system(.body, design: .default, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 4)

            Image(currentPage.screenshotName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .padding(.horizontal, -22)
                .frame(maxWidth: .infinity)
                .frame(height: 460)

            benefitPagesProgressBar

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    private var currencyStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Select currency")
                    .font(.system(.title, design: .default, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                Text("Choose the currency SubHelp uses for subscription prices and totals. You can change this anytime in Settings.")
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(.black.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Currency")
                    .font(.system(.headline, design: .default, weight: .semibold))
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(CurrencyOptions.topCurrencies + CurrencyOptions.otherCurrencies, id: \.code) { currency in
                            Button {
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
            VStack(spacing: 12) {
                Text("Notifications")
                    .font(.system(.title, design: .default, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                Text("Turn on notifications to get renewal alerts before subscriptions charge, plus other helpful updates. You can change this anytime in Settings.")
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(.black.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 4)

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

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: SubHelpAppStorageKey.hasCompletedOnboardingV2)
        UserDefaults.standard.set(true, forKey: "subhelp.didCompleteNotificationSetup")
        RenewalNotificationScheduler.scheduleRenewalReminders()
        hasCompletedCurrencyOnboarding = true
        isPresented = false
        onComplete()
    }
}

private struct BenefitPage {
    let title: String
    let message: String
    let screenshotName: String
}

#Preview {
    CurrencyOnboardingView(isPresented: .constant(true))
}
