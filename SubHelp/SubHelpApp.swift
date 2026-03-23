import SwiftUI

@main
struct SubHelpApp: App {
    @StateObject private var homeViewModel = HomeViewModel()
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("hasCompletedPaywall") private var hasCompletedPaywall = false
    @AppStorage("subscriptionTier") private var subscriptionTierRaw = SubscriptionTier.free.rawValue

    private var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: subscriptionTierRaw) ?? .free }
        set { subscriptionTierRaw = newValue.rawValue }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView {
                    Tab("Subscriptions", systemImage: "diamond.fill") {
                        HomeView(
                            viewModel: homeViewModel,
                            subscriptionTier: subscriptionTier,
                            onTierChange: { tier in
                                UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
                            }
                        )
                    }
                    Tab("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                        HistoryView(viewModel: homeViewModel)
                    }
                    Tab("Help", systemImage: "questionmark.circle.fill") {
                        HelpView(viewModel: homeViewModel)
                    }
                    Tab("Settings", systemImage: "gearshape.fill") {
                        SettingsView()
                    }
                }
                .tint(.blue)
                .preferredColorScheme(darkModeEnabled ? .dark : nil)

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
        }
    }
}
