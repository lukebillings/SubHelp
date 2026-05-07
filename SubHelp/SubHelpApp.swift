import SwiftUI
import UIKit

private enum MainTab: Hashable {
    case subscriptions, history, help, settings
}

private enum SubHelpLaunchStorageKey {
    /// After onboarding, increments on each `didBecomeActive`; paywall shows when count ≥ 2 while still on free tier.
    static let sessionPaywallActivateCount = "subhelp.sessionPaywallActivateCount"
    static let appOpenCount = "subhelp.appOpenCount"
    static let feedbackPromptShown = "subhelp.feedbackPromptShown"
    static let didShowPostPaywallTutorial = "subhelp.didShowPostPaywallTutorial"
}

@main
struct SubHelpApp: App {
    @UIApplicationDelegateAdaptor(SubHelpAppDelegate.self) private var appDelegate
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var premiumSubscriptionProducts = PremiumSubscriptionProducts()
    @AppStorage("hasCompletedCurrencyOnboarding") private var hasCompletedCurrencyOnboarding = false
    @AppStorage("subscriptionTier") private var subscriptionTierRaw = SubscriptionTier.free.rawValue
    @AppStorage(SubHelpLaunchStorageKey.appOpenCount) private var appOpenCount = 0
    @AppStorage(SubHelpLaunchStorageKey.feedbackPromptShown) private var feedbackPromptShown = false
    @AppStorage(SubHelpLaunchStorageKey.didShowPostPaywallTutorial) private var didShowPostPaywallTutorial = false
    @State private var showCurrencyOnboarding = false
    @State private var showSessionPaywall = false
    @State private var showRetentionCheckAlert = false
    @State private var showRetentionHelpChooser = false
    @State private var activeTutorialFlow: InAppTutorialFlow?
    @State private var activeTutorialStepIndex = 0
    /// Skips one `didBecomeActive` bump so finishing onboarding doesn’t immediately show the session paywall.
    @State private var skipNextSessionPaywallActivateBump = false
    @State private var selectedTab: MainTab = .subscriptions

    init() {
        SubscriptionStorage.registerForCloudUpdates()
        SubscriptionStorage.mergeFromCloudOnLaunch()
        let defaults = UserDefaults.standard
        // One-time after this release: show the new onboarding for everyone who is not already on a paid tier.
        // Subscriptions stay in UserDefaults / iCloud; only flags change. Subscribed users skip the sheet.
        if !defaults.bool(forKey: SubHelpAppStorageKey.hasCompletedOnboardingV2) {
            let tierRaw = defaults.string(forKey: "subscriptionTier") ?? SubscriptionTier.free.rawValue
            let tier = SubscriptionTier(rawValue: tierRaw) ?? .free
            if tier == .yearly || tier == .monthly {
                defaults.set(true, forKey: SubHelpAppStorageKey.hasCompletedOnboardingV2)
                defaults.set(true, forKey: "hasCompletedCurrencyOnboarding")
            } else {
                defaults.set(false, forKey: "hasCompletedCurrencyOnboarding")
            }
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
                .onChange(of: selectedTab) { _, _ in
                    SubHelpHaptics.impact(.light)
                }
                .onAppear {
                    RenewalNotificationScheduler.scheduleRenewalReminders()
                    Task {
                        await premiumSubscriptionProducts.syncEntitlementsFromStore()
                        await MainActor.run {
                            reconcileOnboardingAfterStoreTierCheck()
                        }
                        await premiumSubscriptionProducts.refresh()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    SubscriptionStorage.mergeFromCloudOnLaunch()
                    RenewalNotificationScheduler.scheduleRenewalReminders()
                    Task {
                        await premiumSubscriptionProducts.syncEntitlementsFromStore()
                        await MainActor.run {
                            reconcileOnboardingAfterStoreTierCheck()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    if hasCompletedCurrencyOnboarding {
                        appOpenCount += 1
                    }
                    guard hasCompletedCurrencyOnboarding else { return }
                    guard subscriptionTier == .free else {
                        showSessionPaywall = false
                        maybePresentRetentionCheck()
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
                    maybePresentRetentionCheck()
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
                            presentPostPaywallTutorialIfNeeded()
                        }
                    )
                    .environmentObject(premiumSubscriptionProducts)
                    .zIndex(1)
                }

                if let flow = activeTutorialFlow {
                    InAppTutorialOverlay(
                        flow: flow,
                        stepIndex: activeTutorialStepIndex,
                        selectedTab: $selectedTab,
                        onNext: {
                            let nextIndex = activeTutorialStepIndex + 1
                            if nextIndex < flow.steps.count {
                                activeTutorialStepIndex = nextIndex
                            } else {
                                activeTutorialFlow = nil
                                activeTutorialStepIndex = 0
                            }
                        },
                        onSkip: {
                            activeTutorialFlow = nil
                            activeTutorialStepIndex = 0
                        }
                    )
                    .zIndex(3)
                }
            }
            .environmentObject(premiumSubscriptionProducts)
            .fullScreenCover(isPresented: $showCurrencyOnboarding) {
                CurrencyOnboardingView(isPresented: $showCurrencyOnboarding) {
                    selectedTab = .subscriptions
                    presentPostPaywallTutorialIfNeeded()
                }
                .environmentObject(premiumSubscriptionProducts)
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showRetentionHelpChooser) {
                RetentionHelpChooserView(
                    onSelectTopic: { topic in
                        showRetentionHelpChooser = false
                        activeTutorialFlow = .topic(topic)
                        activeTutorialStepIndex = 0
                    },
                    onDismiss: {
                        showRetentionHelpChooser = false
                    }
                )
            }
            .alert("Is SubHelp going good?", isPresented: $showRetentionCheckAlert) {
                Button("Yes") {
                    feedbackPromptShown = true
                }
                Button("No") {
                    feedbackPromptShown = true
                    showRetentionHelpChooser = true
                }
            } message: {
                Text("We can tailor help to what you're trying to do.")
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
                    UserDefaults.standard.set(true, forKey: SubHelpAppStorageKey.hasCompletedOnboardingV2)
                    UserDefaults.standard.set(true, forKey: "hasCompletedCurrencyOnboarding")
                    showCurrencyOnboarding = false
                }
            }
            .onChange(of: showCurrencyOnboarding) { _, showing in
                if showing {
                    showSessionPaywall = false
                }
            }
            .preferredColorScheme(.light)
        }
    }

    /// After StoreKit sync, skip onboarding if the user already has an active subscription (tier may have been stale on disk).
    private func reconcileOnboardingAfterStoreTierCheck() {
        let raw = UserDefaults.standard.string(forKey: "subscriptionTier") ?? SubscriptionTier.free.rawValue
        let tier = SubscriptionTier(rawValue: raw) ?? .free
        guard tier == .yearly || tier == .monthly else { return }
        UserDefaults.standard.set(true, forKey: SubHelpAppStorageKey.hasCompletedOnboardingV2)
        UserDefaults.standard.set(true, forKey: "hasCompletedCurrencyOnboarding")
        showCurrencyOnboarding = false
    }

    private func presentPostPaywallTutorialIfNeeded() {
        guard hasCompletedCurrencyOnboarding else { return }
        guard !didShowPostPaywallTutorial else { return }
        didShowPostPaywallTutorial = true
        activeTutorialFlow = .postPaywall
        activeTutorialStepIndex = 0
    }

    private func maybePresentRetentionCheck() {
        guard hasCompletedCurrencyOnboarding else { return }
        guard appOpenCount >= 3 else { return }
        guard !feedbackPromptShown else { return }
        guard !showCurrencyOnboarding && !showSessionPaywall && activeTutorialFlow == nil else { return }
        showRetentionCheckAlert = true
    }
}

private enum TutorialTarget {
    case addButton
    case summaryCard
    case helpTab

    func rect(in size: CGSize) -> CGRect {
        switch self {
        case .addButton:
            return CGRect(x: 24, y: 260, width: 190, height: 40)
        case .summaryCard:
            return CGRect(x: 20, y: 130, width: size.width - 40, height: 120)
        case .helpTab:
            let tabWidth = size.width / 4
            return CGRect(x: tabWidth * 2, y: size.height - 86, width: tabWidth, height: 60)
        }
    }
}

private struct InAppTutorialStep {
    let title: String
    let message: String
    let tab: MainTab
    let target: TutorialTarget
}

private enum InAppTutorialFlow: Equatable {
    case postPaywall
    case topic(RetentionHelpTopic)

    var steps: [InAppTutorialStep] {
        switch self {
        case .postPaywall:
            return [
                .init(title: "Add subscriptions", message: "Tap + Add Subscription here to start tracking.", tab: .subscriptions, target: .addButton),
                .init(title: "See your totals", message: "This top section shows monthly and yearly spend.", tab: .subscriptions, target: .summaryCard),
                .init(title: "Need help?", message: "Open Help for guided ways to find subscriptions.", tab: .help, target: .helpTab),
            ]
        case .topic(let topic):
            switch topic {
            case .addSubscriptions:
                return [.init(title: topic.rawValue, message: "Use + Add Subscription to quickly add each recurring payment.", tab: .subscriptions, target: .addButton)]
            case .renewalDates:
                return [.init(title: topic.rawValue, message: "Edit each subscription and set next payment dates for accurate reminders.", tab: .subscriptions, target: .summaryCard)]
            case .findForgotten:
                return [.init(title: topic.rawValue, message: "Use the Help tab to check Apple, email receipts, and banking apps.", tab: .help, target: .helpTab)]
            case .cancelGuide:
                return [.init(title: topic.rawValue, message: "Open a subscription and use cancellation guidance from its detail screen.", tab: .subscriptions, target: .summaryCard)]
            case .lowerSpend:
                return [.init(title: topic.rawValue, message: "Start with highest-cost subscriptions and trim from there.", tab: .subscriptions, target: .summaryCard)]
            }
        }
    }
}

private struct InAppTutorialOverlay: View {
    let flow: InAppTutorialFlow
    let stepIndex: Int
    @Binding var selectedTab: MainTab
    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        let safeIndex = min(max(stepIndex, 0), max(flow.steps.count - 1, 0))
        let step = flow.steps[safeIndex]
        GeometryReader { geo in
            let target = step.target.rect(in: geo.size)
            ZStack {
                Color.black.opacity(0.62).ignoresSafeArea()
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(red: 0.96, green: 0.78, blue: 0.22), lineWidth: 2.5)
                    .frame(width: target.width, height: target.height)
                    .position(x: target.midX, y: target.midY)

                VStack(alignment: .leading, spacing: 10) {
                    Text(step.title)
                        .font(.system(.headline, design: .default, weight: .bold))
                    Text(step.message)
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Skip") { onSkip() }
                        Spacer()
                        Button(safeIndex == flow.steps.count - 1 ? "Done" : "Next") { onNext() }
                            .fontWeight(.bold)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(width: min(geo.size.width - 32, 360))
                .position(x: geo.size.width / 2, y: min(max(target.maxY + 84, 190), geo.size.height - 170))
            }
            .onAppear { selectedTab = step.tab }
            .onChange(of: stepIndex) { _, _ in selectedTab = step.tab }
        }
    }
}

private enum RetentionHelpTopic: String, CaseIterable, Identifiable {
    case addSubscriptions = "Add subscriptions faster"
    case renewalDates = "Track renewal dates"
    case findForgotten = "Find forgotten subscriptions"
    case cancelGuide = "Cancel subscriptions"
    case lowerSpend = "Lower monthly spend"

    var id: String { rawValue }
}

private struct RetentionHelpChooserView: View {
    @Environment(\.openURL) private var openURL
    var onSelectTopic: (RetentionHelpTopic) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("What are you trying to do?") {
                    ForEach(RetentionHelpTopic.allCases) { topic in
                        Button(topic.rawValue) {
                            onSelectTopic(topic)
                        }
                    }
                }
                Section {
                    Button("None of these - Request a feature") {
                        if let url = URL(string: "mailto:lukebillingsbusiness@gmail.com?subject=SubHelp%20Feature%20Request") {
                            openURL(url)
                        }
                        onDismiss()
                    }
                }
            }
            .navigationTitle("Help us help you")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }
}

