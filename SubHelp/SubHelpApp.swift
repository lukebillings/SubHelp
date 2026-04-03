import SwiftUI
import UIKit

private enum MainTab: Hashable {
    case subscriptions, history, help, settings
}

private enum SubHelpLaunchStorageKey {
    /// After onboarding, increments on each `didBecomeActive`; paywall shows when count ≥ 2 while still on free tier.
    static let sessionPaywallActivateCount = "subhelp.sessionPaywallActivateCount"
}

@main
struct SubHelpApp: App {
    @UIApplicationDelegateAdaptor(SubHelpAppDelegate.self) private var appDelegate
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var premiumSubscriptionProducts = PremiumSubscriptionProducts()
    @AppStorage("hasCompletedCurrencyOnboarding") private var hasCompletedCurrencyOnboarding = false
    @AppStorage("subscriptionTier") private var subscriptionTierRaw = SubscriptionTier.free.rawValue
    @State private var showCurrencyOnboarding = false
    @State private var showSessionPaywall = false
    /// Skips one `didBecomeActive` bump so finishing onboarding doesn’t immediately show the session paywall.
    @State private var skipNextSessionPaywallActivateBump = false
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
        if defaults.bool(forKey: "hasCompletedCurrencyOnboarding"),
           defaults.object(forKey: SubHelpLaunchStorageKey.sessionPaywallActivateCount) == nil {
            defaults.set(1, forKey: SubHelpLaunchStorageKey.sessionPaywallActivateCount)
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
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    guard hasCompletedCurrencyOnboarding else { return }
                    guard subscriptionTier == .free else {
                        showSessionPaywall = false
                        return
                    }
                    guard !showCurrencyOnboarding else { return }
                    if skipNextSessionPaywallActivateBump {
                        skipNextSessionPaywallActivateBump = false
                        return
                    }
                    let key = SubHelpLaunchStorageKey.sessionPaywallActivateCount
                    var n = UserDefaults.standard.integer(forKey: key)
                    n += 1
                    UserDefaults.standard.set(n, forKey: key)
                    if n >= 2 {
                        showSessionPaywall = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .subhelpResetAllData)) { _ in
                    SubscriptionStorage.resetAllAppDataToFreshInstall()
                    homeViewModel.resetToFreshInstallState()
                    selectedTab = .subscriptions
                    showSessionPaywall = false
                    showCurrencyOnboarding = true
                }

                if showSessionPaywall, subscriptionTier == .free {
                    PaywallView(
                        hasCompletedPaywall: Binding(
                            get: { !showSessionPaywall },
                            set: { if $0 { showSessionPaywall = false } }
                        ),
                        selectedTier: Binding(
                            get: { SubscriptionTier(rawValue: subscriptionTierRaw) ?? .free },
                            set: { subscriptionTierRaw = $0.rawValue }
                        ),
                        onSelect: { tier in
                            UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
                        },
                        freeDismissCountdownSeconds: 5
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
            .onAppear {
                if !hasCompletedCurrencyOnboarding {
                    showCurrencyOnboarding = true
                }
            }
            .onChange(of: hasCompletedCurrencyOnboarding) { _, done in
                guard done else { return }
                let key = SubHelpLaunchStorageKey.sessionPaywallActivateCount
                let n = UserDefaults.standard.integer(forKey: key)
                if n < 1 {
                    UserDefaults.standard.set(1, forKey: key)
                }
                skipNextSessionPaywallActivateBump = true
            }
            .onChange(of: subscriptionTierRaw) { _, _ in
                if subscriptionTier != .free {
                    showSessionPaywall = false
                }
            }
            .onChange(of: showCurrencyOnboarding) { _, showing in
                if showing {
                    showSessionPaywall = false
                }
            }
        }
    }
}
