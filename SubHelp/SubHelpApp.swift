import SwiftUI
import UIKit

private enum MainTab: Hashable {
    case subscriptions, history, help, settings
}

private enum SubHelpLaunchStorageKey {
    /// After onboarding, increments on each `didBecomeActive`; used so the first return visit can show a paywall.
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
    @AppStorage(SubHelpAppStorageKey.didShowSessionPaywall) private var didShowSessionPaywall = false
    @State private var showCurrencyOnboarding = false
    @State private var showSessionPaywall = false
    @State private var showRetentionCheckAlert = false
    @State private var showRetentionHelpChooser = false
    @State private var activeTutorialFlow: InAppTutorialFlow?
    @State private var activeTutorialStepIndex = 0
    /// Skips one `didBecomeActive` bump so finishing onboarding doesn’t immediately show the session paywall.
    @State private var skipNextSessionPaywallActivateBump = false
    @State private var selectedTab: MainTab = .subscriptions
    @State private var trialPrompt: Subscription?
    @State private var deferredTrialIDs: Set<UUID> = []

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
        WidgetSnapshotPublisher.refreshFromStorage()
    }

    private var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: subscriptionTierRaw) ?? .free }
        set { subscriptionTierRaw = newValue.rawValue }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView(selection: $selectedTab) {
                    Tab("Subscriptions", systemImage: "creditcard", value: MainTab.subscriptions) {
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
                    Tab("Help", systemImage: "questionmark.circle", value: MainTab.help) {
                        HelpView(viewModel: homeViewModel)
                    }
                    Tab("Settings", systemImage: "gearshape", value: MainTab.settings) {
                        SettingsView()
                    }
                }
                .tint(.blue)
                .subHelpTabBarBehavior()
                .onChange(of: selectedTab) { _, _ in
                    SubHelpHaptics.impact(.light)
                }
                .onAppear {
                    RenewalNotificationScheduler.scheduleRenewalReminders()
                    applyPendingTrialDecision()
                    presentTrialPromptIfNeeded()
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
                    WidgetSnapshotPublisher.refreshFromStorage()
                    RenewalNotificationScheduler.scheduleRenewalReminders()
                    applyPendingTrialDecision()
                    presentTrialPromptIfNeeded()
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
                    guard !showCurrencyOnboarding else { return }
                    applyPendingTrialDecision()
                    presentTrialPromptIfNeeded()
                    if skipNextSessionPaywallActivateBump {
                        skipNextSessionPaywallActivateBump = false
                        return
                    }
                    maybePresentSessionPaywall()
                    maybePresentRetentionCheck()
                }
                .onReceive(NotificationCenter.default.publisher(for: TrialPromptCenter.notification)) { _ in
                    applyPendingTrialDecision()
                }
                .onReceive(NotificationCenter.default.publisher(for: .subhelpResetAllData)) { _ in
                    SubscriptionStorage.resetAllAppDataToFreshInstall()
                    homeViewModel.resetToFreshInstallState()
                    selectedTab = .subscriptions
                    showSessionPaywall = false
                    didShowSessionPaywall = false
                    showCurrencyOnboarding = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .subhelpTriggerRetentionCheck)) { _ in
                    selectedTab = .subscriptions
                    showRetentionCheckAlert = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .subhelpReplayPostPaywallTutorial)) { _ in
                    selectedTab = .subscriptions
                    activeTutorialFlow = .postPaywall
                    activeTutorialStepIndex = 0
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
                        showsOnboardingProgress: false,
                        allowsDismiss: true,
                        headline: sessionPaywallHeadline,
                        subheadline: String(localized: "Unlock unlimited plus reminders."),
                        onSelect: { tier in
                            UserDefaults.standard.set(tier.rawValue, forKey: "subscriptionTier")
                            presentPostPaywallTutorialIfNeeded()
                        }
                    )
                    .environmentObject(premiumSubscriptionProducts)
                    .zIndex(1)
                }

                if let flow = activeTutorialFlow {
                    let hasSubscriptions = !homeViewModel.subscriptions.isEmpty
                    let steps = flow.steps(hasSubscriptions: hasSubscriptions)
                    InAppTutorialOverlay(
                        flow: flow,
                        steps: steps,
                        stepIndex: activeTutorialStepIndex,
                        selectedTab: $selectedTab,
                        onNext: {
                            let nextIndex = activeTutorialStepIndex + 1
                            if nextIndex < steps.count {
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
            .alert(
                "Free trial",
                isPresented: Binding(
                    get: { trialPrompt != nil },
                    set: { if !$0 { trialPrompt = nil } }
                ),
                presenting: trialPrompt
            ) { sub in
                Button("I kept it") {
                    homeViewModel.keepTrial(id: sub.id)
                    trialPrompt = nil
                    presentTrialPromptIfNeeded()
                }
                Button("I cancelled", role: .destructive) {
                    homeViewModel.removeSubscription(sub)
                    trialPrompt = nil
                    presentTrialPromptIfNeeded()
                }
                Button("Decide later") {
                    deferredTrialIDs.insert(sub.id)
                    trialPrompt = nil
                }
            } message: { sub in
                let end = sub.trialEndDate ?? sub.nextPaymentDate
                let ended = Calendar.current.startOfDay(for: end) <= Calendar.current.startOfDay(for: Date())
                Text(ended
                     ? "\(sub.name) trial has ended. Keep it on your list, or mark it cancelled?"
                     : "\(sub.name) trial is still running. Keep it on your list, or mark it cancelled?")
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

    /// First return visit after onboarding, once the user has actually tracked something.
    private func maybePresentSessionPaywall() {
        guard subscriptionTier == .free else { return }
        guard hasCompletedCurrencyOnboarding else { return }
        guard !didShowSessionPaywall else { return }
        guard appOpenCount >= 2 else { return }
        let trackedCount = homeViewModel.subscriptions.count
        guard (1...FreePlanLimits.subscriptionCount).contains(trackedCount) else { return }
        guard trialPrompt == nil else { return }
        guard !showCurrencyOnboarding && !showSessionPaywall && activeTutorialFlow == nil && !showRetentionCheckAlert else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard subscriptionTier == .free else { return }
            guard !didShowSessionPaywall else { return }
            guard !showCurrencyOnboarding && !showSessionPaywall && activeTutorialFlow == nil && !showRetentionCheckAlert else { return }
            guard trialPrompt == nil else { return }
            guard (1...FreePlanLimits.subscriptionCount).contains(homeViewModel.subscriptions.count) else { return }
            didShowSessionPaywall = true
            showSessionPaywall = true
        }
    }

    private var sessionPaywallHeadline: String {
        let count = homeViewModel.subscriptions.count
        if count == 1 {
            return String(localized: "You're tracking 1 subscription")
        }
        return String(format: String(localized: "You're tracking %d"), count)
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
        guard trialPrompt == nil else { return }
        let dueTrials = homeViewModel.trialsNeedingDecision()
        guard dueTrials.allSatisfy({ deferredTrialIDs.contains($0.id) }) else { return }
        guard !showCurrencyOnboarding && !showSessionPaywall && activeTutorialFlow == nil else { return }
        if subscriptionTier == .free,
           !didShowSessionPaywall,
           (1...FreePlanLimits.subscriptionCount).contains(homeViewModel.subscriptions.count) {
            return
        }
        showRetentionCheckAlert = true
    }

    private func presentTrialPromptIfNeeded() {
        guard hasCompletedCurrencyOnboarding else { return }
        guard trialPrompt == nil else { return }
        guard !showCurrencyOnboarding && !showSessionPaywall && activeTutorialFlow == nil && !showRetentionCheckAlert else { return }
        guard let due = homeViewModel.trialsNeedingDecision().first(where: { !deferredTrialIDs.contains($0.id) }) else { return }
        trialPrompt = due
    }

    private func applyPendingTrialDecision() {
        guard let pending = TrialPromptCenter.pending else { return }
        TrialPromptCenter.pending = nil
        switch pending.decision {
        case .keep:
            homeViewModel.keepTrial(id: pending.id)
            if trialPrompt?.id == pending.id { trialPrompt = nil }
        case .cancel:
            if let sub = homeViewModel.subscriptions.first(where: { $0.id == pending.id }) {
                homeViewModel.removeSubscription(sub)
            }
            if trialPrompt?.id == pending.id { trialPrompt = nil }
        case .ask:
            if let sub = homeViewModel.subscriptions.first(where: { $0.id == pending.id && $0.isTrial }) {
                deferredTrialIDs.remove(sub.id)
                trialPrompt = sub
                return
            }
        }
        presentTrialPromptIfNeeded()
    }
}

private enum TutorialTarget {
    case addButton
    case historyTab
    case helpTab

    func rect(in size: CGSize) -> CGRect {
        switch self {
        case .addButton:
            return CGRect(x: 24, y: 260, width: 190, height: 40)
        case .historyTab:
            let tabWidth = size.width / 4
            return CGRect(x: tabWidth, y: size.height - 86, width: tabWidth, height: 60)
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

    func steps(hasSubscriptions: Bool) -> [InAppTutorialStep] {
        switch self {
        case .postPaywall:
            if hasSubscriptions {
                return [
                    .init(title: "Here you can add subscriptions", message: "Tap + Add Subscription here to start tracking.", tab: .subscriptions, target: .addButton),
                    .init(title: "Here you can view a history of the subscriptions you cancelled", message: "Use History to review anything you have unsubscribed from.", tab: .history, target: .historyTab),
                    .init(title: "Here you can find tips on saving", message: "Open Help for saving tips and guidance.", tab: .help, target: .helpTab),
                ]
            } else {
                return [
                    .init(title: "Here you can add subscriptions", message: "Tap Add Subscription on this screen to start tracking.", tab: .subscriptions, target: .addButton),
                    .init(title: "Here you can view a history of the subscriptions you cancelled", message: "Use History to review anything you have unsubscribed from.", tab: .history, target: .historyTab),
                    .init(title: "Here you can find tips on saving", message: "Open Help for saving tips and guidance.", tab: .help, target: .helpTab),
                ]
            }
        case .topic(let topic):
            switch topic {
            case .addSubscriptions:
                return [.init(title: topic.rawValue, message: "Use + Add Subscription to quickly add each recurring payment.", tab: .subscriptions, target: .addButton)]
            case .renewalDates:
                if hasSubscriptions {
                    return [.init(title: topic.rawValue, message: "Edit each subscription and set next payment dates for accurate reminders.", tab: .history, target: .historyTab)]
                } else {
                    return [.init(title: topic.rawValue, message: "Add your first subscription, then set its next payment date for reminders.", tab: .subscriptions, target: .addButton)]
                }
            case .findForgotten:
                return [.init(title: topic.rawValue, message: "Use the Help tab to check Apple, email receipts, and banking apps.", tab: .help, target: .helpTab)]
            case .cancelGuide:
                if hasSubscriptions {
                    return [.init(title: topic.rawValue, message: "Open History to review cancelled subscriptions and what you have already cut.", tab: .history, target: .historyTab)]
                } else {
                    return [.init(title: topic.rawValue, message: "Add subscriptions first, then use Help for cancellation guidance.", tab: .help, target: .helpTab)]
                }
            case .lowerSpend:
                if hasSubscriptions {
                    return [.init(title: topic.rawValue, message: "Use Help for saving ideas, then track progress in History.", tab: .help, target: .helpTab)]
                } else {
                    return [.init(title: topic.rawValue, message: "Add subscriptions first so SubHelp can show where to save.", tab: .subscriptions, target: .addButton)]
                }
            }
        }
    }
}

private struct InAppTutorialOverlay: View {
    let flow: InAppTutorialFlow
    let steps: [InAppTutorialStep]
    let stepIndex: Int
    @Binding var selectedTab: MainTab
    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        let safeIndex = min(max(stepIndex, 0), max(steps.count - 1, 0))
        let step = steps[safeIndex]
        GeometryReader { geo in
            let target = step.target.rect(in: geo.size)
            ZStack {
                Color.black.opacity(0.62).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    Text(step.title)
                        .font(.system(.headline, design: .default, weight: .bold))
                    Text(step.message)
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                    HStack {
                        if flow != .postPaywall {
                            Button("Skip") { onSkip() }
                                .buttonStyle(.subHelp(.glass, tint: .secondary, compact: true))
                        }
                        Spacer()
                        Button(safeIndex == steps.count - 1 ? "Done" : "Next") { onNext() }
                            .buttonStyle(.subHelp(compact: true))
                    }
                }
                .padding(18)
                .frame(width: min(geo.size.width - 32, 360))
                .subHelpPanel(cornerRadius: 26)
                .position(x: geo.size.width / 2, y: min(max(target.maxY + 84, 190), geo.size.height - 170))
            }
            .onAppear { selectedTab = step.tab }
            .onChange(of: stepIndex) { _, _ in selectedTab = step.tab }
        }
    }
}

private enum RetentionHelpTopic: String, CaseIterable, Identifiable {
    case addSubscriptions = "Add subscriptions"
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
                        if let url = URL(string: "mailto:subhelp@outlook.com?subject=SubHelp%20Feature%20Request") {
                            openURL(url)
                        }
                        onDismiss()
                    }
                }
            }
            .navigationTitle("Help us help you")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SubHelpDoneButton(action: onDismiss)
                }
            }
        }
    }
}

