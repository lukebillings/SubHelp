import SwiftUI
import UIKit

private enum MainTab: Hashable {
    case subscriptions, history, help, settings
}

@main
struct SubHelpApp: App {
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var premiumSubscriptionProducts = PremiumSubscriptionProducts()
    @AppStorage("hasCompletedPaywall") private var hasCompletedPaywall = false
    @AppStorage("hasCompletedCurrencyOnboarding") private var hasCompletedCurrencyOnboarding = false
    @AppStorage("subscriptionTier") private var subscriptionTierRaw = SubscriptionTier.free.rawValue
    @State private var showCurrencyOnboarding = false
    @State private var selectedTab: MainTab = .subscriptions

    init() {
        SubscriptionStorage.registerForCloudUpdates()
        SubscriptionStorage.mergeFromCloudOnLaunch()
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "hasCompletedCurrencyOnboarding") == nil,
           defaults.bool(forKey: "hasCompletedPaywall") {
            defaults.set(true, forKey: "hasCompletedCurrencyOnboarding")
        }
        if defaults.bool(forKey: "hasCompletedCurrencyOnboarding"),
           defaults.object(forKey: "subhelp.didCompleteNotificationSetup") == nil {
            defaults.set(true, forKey: "subhelp.didCompleteNotificationSetup")
        }
        _homeViewModel = StateObject(wrappedValue: HomeViewModel())
    }

    private var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: subscriptionTierRaw) ?? .free }
        set { subscriptionTierRaw = newValue.rawValue }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView(selection: $selectedTab) {
                    Tab("Subscriptions", systemImage: "creditcard.fill", value: MainTab.subscriptions) {
                        HomeView(
                            viewModel: homeViewModel,
                            subscriptionTier: subscriptionTier,
                            onTierChange: { tier in
                                UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
                            }
                        )
                    }
                    Tab("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90", value: MainTab.history) {
                        HistoryView(viewModel: homeViewModel)
                    }
                    Tab("Help", systemImage: "questionmark.circle.fill", value: MainTab.help) {
                        HelpView(viewModel: homeViewModel)
                    }
                    Tab("Settings", systemImage: "gearshape.fill", value: MainTab.settings) {
                        SettingsView()
                    }
                }
                .tint(.blue)
                .onAppear {
                    RenewalNotificationScheduler.scheduleRenewalReminders()
                    Task {
                        await premiumSubscriptionProducts.syncEntitlementsFromStore()
                        await premiumSubscriptionProducts.refresh()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    SubscriptionStorage.mergeFromCloudOnLaunch()
                    RenewalNotificationScheduler.scheduleRenewalReminders()
                    Task {
                        await premiumSubscriptionProducts.syncEntitlementsFromStore()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .subhelpResetAllData)) { _ in
                    SubscriptionStorage.resetAllAppDataToFreshInstall()
                    homeViewModel.resetToFreshInstallState()
                    selectedTab = .subscriptions
                }

                // Paywall on first launch – blocks until user selects a plan
                if !hasCompletedPaywall {
                    PaywallView(
                        hasCompletedPaywall: Binding(
                            get: { hasCompletedPaywall },
                            set: { UserDefaults.standard.set($0, forKey: "hasCompletedPaywall") }
                        ),
                        selectedTier: Binding(
                            get: { subscriptionTier },
                            set: { UserDefaults.standard.set($0.rawValue, forKey: "subscriptionTier") }
                        ),
                        onSelect: { tier in
                            UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
                            UserDefaults.standard.set(true, forKey: "hasCompletedPaywall")
                        }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .environmentObject(premiumSubscriptionProducts)
            .sheet(isPresented: $showCurrencyOnboarding) {
                CurrencyOnboardingView(isPresented: $showCurrencyOnboarding) {
                    selectedTab = .subscriptions
                }
                .interactiveDismissDisabled()
            }
            .onChange(of: hasCompletedPaywall) { _, completed in
                guard completed, !hasCompletedCurrencyOnboarding else { return }
                DispatchQueue.main.async {
                    showCurrencyOnboarding = true
                }
            }
            .onAppear {
                if hasCompletedPaywall, !hasCompletedCurrencyOnboarding {
                    showCurrencyOnboarding = true
                }
            }
        }
    }
}
