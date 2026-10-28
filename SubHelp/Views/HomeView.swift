import SwiftUI
import StoreKit

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    var subscriptionTier: SubscriptionTier
    var onTierChange: (SubscriptionTier) -> Void

    @Environment(\.requestReview) private var requestReview
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @State private var selectedSubscription: Subscription?
    @State private var showAddSheet = false
    @State private var showQuickStartGuide = false
    @State private var showSavingsCard = false
    @State private var showUpgradePaywall = false
    @State private var showLimitNudge = false
    /// True after this session’s first successful add, so existing installs are not prompted on launch.
    @State private var addedSubscriptionThisSession = false
    @AppStorage(SubHelpAppStorageKey.didShowFreeLimitNudge) private var didShowFreeLimitNudge = false
    @AppStorage(SubHelpAppStorageKey.didDismissFreeLimitBanner) private var didDismissFreeLimitBanner = false
    @AppStorage(SubHelpAppStorageKey.didRequestReviewAfterFirstSubscriptions) private var didRequestReviewAfterFirstSubscriptions = false
    @Namespace private var cardTransition

    /// Free accounts can track up to three subscriptions. The paywall appears when they try to add a fourth.
    private var subscriptionLimit: Int {
        subscriptionTier == .free ? FreePlanLimits.subscriptionCount : .max
    }

    private var canAddMore: Bool {
        viewModel.subscriptions.count < subscriptionLimit
    }

    private var isAtFreeLimit: Bool {
        subscriptionTier == .free && viewModel.subscriptions.count >= FreePlanLimits.subscriptionCount
    }

    private var shouldShowLimitBanner: Bool {
        isAtFreeLimit && !didDismissFreeLimitBanner
    }

    private func addTrackedSubscriptionOrPaywall(_ newSub: Subscription, dismissing: () -> Void) {
        if canAddMore {
            viewModel.addSubscription(newSub)
            addedSubscriptionThisSession = true
        } else {
            dismissing()
            requestHardPaywall()
        }
    }

    private var isBlockingReviewPrompt: Bool {
        showAddSheet
            || showQuickStartGuide
            || showLimitNudge
            || showUpgradePaywall
            || showSavingsCard
            || selectedSubscription != nil
    }

    /// Asks for an App Store rating once the add flow is gone and the new list is on screen.
    private func presentReviewAfterFirstSubscriptionsIfNeeded() {
        guard !didRequestReviewAfterFirstSubscriptions else { return }
        guard addedSubscriptionThisSession else { return }
        guard viewModel.subscriptions.count >= 1 else { return }
        guard !isBlockingReviewPrompt else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard !didRequestReviewAfterFirstSubscriptions else { return }
            guard addedSubscriptionThisSession else { return }
            guard viewModel.subscriptions.count >= 1 else { return }
            guard !isBlockingReviewPrompt else { return }
            didRequestReviewAfterFirstSubscriptions = true
            requestReview()
        }
    }

    private func requestHardPaywall() {
        didShowFreeLimitNudge = true
        showLimitNudge = false
        showUpgradePaywall = true
    }

    private func presentLimitNudgeWhenReady() {
        guard subscriptionTier == .free else { return }
        guard viewModel.subscriptions.count >= FreePlanLimits.subscriptionCount else { return }
        guard !didShowFreeLimitNudge else { return }
        guard !showAddSheet, !showQuickStartGuide, !showUpgradePaywall else { return }
        didShowFreeLimitNudge = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard subscriptionTier == .free else { return }
            guard !showAddSheet, !showQuickStartGuide, !showUpgradePaywall else { return }
            showLimitNudge = true
        }
    }

    private func presentUpgradePaywallAfterNudge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showUpgradePaywall = true
        }
    }

    var body: some View {
        Group {
            if viewModel.subscriptions.isEmpty {
                welcomeState
            } else {
                VStack(spacing: 0) {
                    summarySection
                    segmentControl

                    switch viewModel.viewMode {
                    case .list:
                        sortBar
                        // Always keep a ScrollView here so this region fills remaining height; a bare Text
                        // made the VStack shrink and the tab vertically centered content (huge gap on top).
                        ScrollView {
                            if viewModel.subscriptionsForDisplay.isEmpty, !viewModel.subscriptions.isEmpty {
                                Text("No subscriptions in this category.")
                                    .font(.system(.subheadline, design: .default, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 24)
                            } else {
                                cardsList
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    case .calendar:
                        calendarFilterBar
                        calendarSection
                    case .board:
                        calendarFilterBar
                        SubscriptionBoardView(
                            viewModel: viewModel,
                            currencyCode: currencyCode,
                            selectedSubscription: $selectedSubscription,
                            cardTransition: cardTransition
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background { SubHelpBackdrop() }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSubscriptionView { newSub in
                addTrackedSubscriptionOrPaywall(newSub, dismissing: { showAddSheet = false })
            }
        }
        .sheet(isPresented: $showQuickStartGuide) {
            QuickStartGuideView { newSub in
                addTrackedSubscriptionOrPaywall(newSub, dismissing: { showQuickStartGuide = false })
            }
        }
        .sheet(isPresented: $showLimitNudge) {
            FreePlanLimitNudgeView(
                onUpgrade: {
                    showLimitNudge = false
                    presentUpgradePaywallAfterNudge()
                },
                onDismiss: {
                    showLimitNudge = false
                }
            )
        }
        .sheet(isPresented: $showUpgradePaywall) {
            PaywallView(
                hasCompletedPaywall: Binding(
                    get: { !showUpgradePaywall },
                    set: { if $0 { showUpgradePaywall = false } }
                ),
                selectedTier: Binding(
                    get: { subscriptionTier },
                    set: { onTierChange($0) }
                ),
                showsOnboardingProgress: false,
                allowsDismiss: true,
                onSelect: { tier in
                    onTierChange(tier)
                }
            )
        }
        .onChange(of: showAddSheet) { _, showing in
            if !showing {
                presentLimitNudgeWhenReady()
                presentReviewAfterFirstSubscriptionsIfNeeded()
            }
        }
        .onChange(of: showQuickStartGuide) { _, showing in
            if !showing {
                presentLimitNudgeWhenReady()
                presentReviewAfterFirstSubscriptionsIfNeeded()
            }
        }
        .onChange(of: showLimitNudge) { _, showing in
            if !showing { presentReviewAfterFirstSubscriptionsIfNeeded() }
        }
        .onChange(of: showUpgradePaywall) { _, showing in
            if !showing { presentReviewAfterFirstSubscriptionsIfNeeded() }
        }
        .onChange(of: subscriptionTier) { _, tier in
            if tier != .free {
                showLimitNudge = false
                showUpgradePaywall = false
            }
        }
        .sheet(isPresented: $showSavingsCard) {
            SavingsHologramCardView(
                savedAmountPerMonth: viewModel.savedAmount,
                currencyCode: currencyCode
            )
        }
        .sheet(item: $selectedSubscription) { sub in
            NavigationStack {
                SubscriptionDetailView(
                    subscription: Binding(
                        get: {
                            viewModel.subscriptions.first(where: { $0.id == sub.id }) ?? sub
                        },
                        set: { updated in
                            viewModel.saveSubscriptionEdits(updated)
                        }
                    ),
                    onUnsubscribe: { cancelled in
                        viewModel.removeSubscription(cancelled)
                    }
                )
            }
            .navigationTransition(.zoom(sourceID: sub.id, in: cardTransition))
        }
    }

    // MARK: - Welcome / Empty State

    private var welcomeState: some View {
        ZStack {
            SubHelpBackdrop()

            ScrollView {
                VStack(spacing: 0) {
                    // Mascot
                    Image("ShibaMascot")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                        .padding(.bottom, 20)

                    Text("Know what subscriptions you have?")
                        .font(.system(.title2, design: .default, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)

                    Text("Get started by manually adding a subscription.")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)

                    Button {
                        if canAddMore {
                            showAddSheet = true
                        } else {
                            requestHardPaywall()
                        }
                    } label: {
                        Label("Add Subscription", systemImage: "plus")
                    }
                    .buttonStyle(.subHelp(fullWidth: true))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                    Text("Not sure where to start?")
                        .font(.system(.subheadline, design: .default, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)

                    Button {
                        if canAddMore {
                            showQuickStartGuide = true
                        } else {
                            requestHardPaywall()
                        }
                    } label: {
                        Text("Help Find Subscriptions")
                    }
                    .buttonStyle(.subHelp(.glass, fullWidth: true))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
                .padding(.top, 40)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription Spend")
                        .font(.system(.title3, design: .default, weight: .bold))
                        .foregroundStyle(.primary)

                    (Text("\(CurrencyOptions.formatPresentation(amount: viewModel.totalPerMonth, currencyCode: currencyCode)) ")
                        .font(.system(.title, design: .rounded, weight: .bold))
                     + Text("/month")
                        .font(.system(.title3, design: .default, weight: .medium))
                        .foregroundStyle(.secondary))
                        .subHelpNumeric(value: viewModel.totalPerMonth)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    (Text("\(CurrencyOptions.formatPresentation(amount: viewModel.totalPerYear, currencyCode: currencyCode)) ")
                        .font(.system(.title, design: .rounded, weight: .bold))
                     + Text("/year")
                        .font(.system(.title3, design: .default, weight: .medium))
                        .foregroundStyle(.secondary))
                        .subHelpNumeric(value: viewModel.totalPerYear)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showSavingsCard = true
                } label: {
                    ZStack(alignment: .bottom) {
                        Image("ShibaMascot")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .offset(y: -22)

                        VStack(spacing: 1) {
                            Text(CurrencyOptions.formatPresentation(amount: viewModel.savedAmount * 12, currencyCode: currencyCode))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .subHelpNumeric(value: viewModel.savedAmount)
                            Text("Yearly Savings")
                                .font(.system(.caption2, design: .default, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .subHelpGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: SubHelpTheme.savingsGold)
                    }
                }
                .buttonStyle(.subHelpPressable)
            }

            if shouldShowLimitBanner {
                freeLimitBanner
            }

            HStack(spacing: 8) {
                Button {
                    if canAddMore {
                        showAddSheet = true
                    } else {
                        requestHardPaywall()
                    }
                } label: {
                    Label("Add Subscription", systemImage: "plus")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(.subHelp(compact: true, fullWidth: true))
                .frame(maxWidth: .infinity)

                Button {
                    if canAddMore {
                        showQuickStartGuide = true
                    } else {
                        requestHardPaywall()
                    }
                } label: {
                    Text("Help Find Subscriptions")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(.subHelp(.glass, compact: true, fullWidth: true))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .padding(.bottom, 8)
        .subHelpPanel()
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var freeLimitBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                SubHelpHaptics.impact(.light)
                requestHardPaywall()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: String(localized: "You've used your %d free slots"), FreePlanLimits.subscriptionCount))
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Upgrade to add more.")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                SubHelpHaptics.impact(.light)
                didDismissFreeLimitBanner = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(.caption, design: .default, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background {
            PaywallGlassPanel(cornerRadius: 16, borderEmphasized: true)
        }
    }

    // MARK: - Segment

    private var segmentControl: some View {
        Picker("View", selection: $viewModel.viewMode) {
            ForEach(SubscriptionViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Category filter (same row as sort in list; calendar uses filter only)

    private var categoryFilterMenu: some View {
        Menu {
            ForEach(viewModel.categoryFilterMenuOptions, id: \.self) { option in
                Button {
                    viewModel.categoryFilter = option
                } label: {
                    HStack {
                        Text(option.displayTitle)
                        if viewModel.categoryFilter == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(viewModel.categoryFilter.displayTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .animation(nil, value: viewModel.categoryFilter)
            }
            .font(.system(.subheadline, design: .default, weight: .medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .subHelpGlass(in: Capsule(), interactive: true)
            .contentShape(Capsule())
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(viewModel.sortOption.rawValue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .animation(nil, value: viewModel.sortOption)
            }
            .font(.system(.subheadline, design: .default, weight: .medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .subHelpGlass(in: Capsule(), interactive: true)
            .contentShape(Capsule())
        }
    }

    private var calendarFilterBar: some View {
        HStack {
            categoryFilterMenu
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - Sort

    private var sortBar: some View {
        HStack(alignment: .center, spacing: 12) {
            categoryFilterMenu
                .frame(maxWidth: .infinity, alignment: .leading)
            sortMenu
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - List

    private var cardsList: some View {
        LazyVStack(spacing: 14) {
            ForEach(viewModel.subscriptionsForDisplay) { sub in
                Button { selectedSubscription = sub } label: {
                    subscriptionCard(sub)
                }
                .buttonStyle(.subHelpPressable)
                .matchedTransitionSource(id: sub.id, in: cardTransition)
                .subHelpScrollFade()
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(SubHelpTheme.smooth, value: viewModel.subscriptionsForDisplay.map(\.id))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private func subscriptionCard(_ sub: Subscription) -> some View {
        let note = sub.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasStage = sub.stage != .keep
        let showLabels = hasStage || !note.isEmpty || sub.isTrial
        return HStack(alignment: .center, spacing: 12) {
            SubscriptionCategoryMark(category: sub.category)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(sub.name)
                        .font(.system(.headline, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(CurrencyOptions.formatPresentation(amount: sub.price, currencyCode: currencyCode))
                            .font(.system(.headline, design: .default, weight: .bold))
                            .foregroundStyle(.white)
                        Text(sub.frequency.shortLabel)
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                Text(sub.isTrial
                     ? "Trial ends: \(viewModel.nextPaymentString(for: sub.trialEndDate ?? sub.nextPaymentDate))"
                     : "Next payment: \(viewModel.nextPaymentString(for: sub.nextPaymentDate))")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if showLabels {
                    HStack(spacing: 6) {
                        if sub.isTrial {
                            SubscriptionLabelPill(text: "On free trial", kind: .trial)
                        }
                        if hasStage {
                            SubscriptionLabelPill(text: sub.stage.rawValue, kind: .stage(sub.stage))
                        }
                        if !note.isEmpty {
                            SubscriptionLabelPill(text: note, kind: .note)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .subHelpColorCard(sub.color)
    }

    // MARK: - Calendar

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    /// Same gold family as the yearly savings badge on the mascot.
    private let calendarTodayGold = Color(red: 1.0, green: 0.84, blue: 0.0)

    private func calendarDayIsToday(day: Int, inMonthContaining date: Date) -> Bool {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: date)
        comps.day = day
        guard let d = cal.date(from: comps) else { return false }
        return cal.isDateInToday(d)
    }

    @ViewBuilder
    private func calendarDayNumberBackground(isSelected: Bool, isToday: Bool) -> some View {
        if isToday {
            Circle().fill(calendarTodayGold)
        } else if isSelected {
            Circle().fill(Color.blue)
        } else {
            Color.clear
        }
    }

    private var calendarSection: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Month navigation
                HStack {
                    Button { withAnimation(SubHelpTheme.smooth) { viewModel.changeMonth(by: -1) } } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(.body, design: .default, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .subHelpGlass(in: Circle(), interactive: true)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(viewModel.monthYearString)
                        .font(.system(.headline, design: .default, weight: .bold))
                        .contentTransition(.numericText())
                        .animation(SubHelpTheme.smooth, value: viewModel.monthYearString)
                    Spacer()
                    Button { withAnimation(SubHelpTheme.smooth) { viewModel.changeMonth(by: 1) } } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(.body, design: .default, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .subHelpGlass(in: Circle(), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Weekday headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)

                // Day grid
                let totalDays = viewModel.daysInMonth(viewModel.selectedDate)
                let offset = viewModel.firstWeekdayOfMonth(viewModel.selectedDate)
                let selectedDay = Calendar.current.component(.day, from: viewModel.selectedDate)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(0..<(offset + totalDays), id: \.self) { index in
                        if index < offset {
                            Color.clear.frame(height: 40)
                        } else {
                            let day = index - offset + 1
                            let colors = viewModel.subscriptionColors(forDay: day, inMonth: viewModel.selectedDate)
                            let isSelected = day == selectedDay
                            let isToday = calendarDayIsToday(day: day, inMonthContaining: viewModel.selectedDate)

                            Button {
                                let cal = Calendar.current
                                var comps = cal.dateComponents([.year, .month], from: viewModel.selectedDate)
                                comps.day = day
                                if let newDate = cal.date(from: comps) {
                                    viewModel.selectedDate = newDate
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(day)")
                                        .font(.system(.body, design: .default, weight: (isSelected || isToday) ? .bold : .regular))
                                        .foregroundStyle(
                                            isSelected
                                                ? Color.white
                                                : (isToday ? Color(red: 0.2, green: 0.14, blue: 0.02) : Color.primary)
                                        )
                                        .frame(width: 28, height: 28)
                                        .background(calendarDayNumberBackground(isSelected: isSelected, isToday: isToday))
                                        .clipShape(Circle())

                                    // Colored dots for subscriptions
                                    HStack(spacing: 2) {
                                        ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                                            Circle()
                                                .fill(color)
                                                .frame(width: 5, height: 5)
                                        }
                                    }
                                    .frame(height: 5)
                                }
                                .frame(height: 40)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12)

                // Subscriptions for selected date
                let subsForDate = viewModel.subscriptions(for: viewModel.selectedDate)

                if subsForDate.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No subscriptions due")
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(subsForDate) { sub in
                            Button { selectedSubscription = sub } label: {
                                calendarCard(sub)
                            }
                            .buttonStyle(.subHelpPressable)
                            .matchedTransitionSource(id: sub.id, in: cardTransition)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func calendarCard(_ sub: Subscription) -> some View {
        VStack(spacing: 6) {
            SubscriptionCategoryMark(category: sub.category, size: 32)
            Text(sub.name)
                .font(.system(.subheadline, design: .default, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(CurrencyOptions.formatPresentation(amount: sub.price, currencyCode: currencyCode))
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundStyle(.white)
            Text(sub.isTrial ? "On free trial" : sub.frequency.rawValue)
                .font(.system(.caption, design: .default, weight: .semibold))
                .foregroundStyle(sub.isTrial ? Color(red: 0.55, green: 0.28, blue: 0.95) : .white.opacity(0.8))
                .padding(.horizontal, sub.isTrial ? 8 : 0)
                .padding(.vertical, sub.isTrial ? 3 : 0)
                .background {
                    if sub.isTrial {
                        Capsule().fill(.white)
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .subHelpColorCard(sub.color)
    }
}

// MARK: - Savings Trading Card (holographic gold, 3D tilt with finger)

private struct SavingsHologramCardView: View {
    @Environment(\.dismiss) private var dismiss
    let savedAmountPerMonth: Decimal
    let currencyCode: String

    /// Normalised tilt: -1…1 on each axis
    @State private var tiltX: CGFloat = 0
    @State private var tiltY: CGFloat = 0
    @State private var isDragging = false

    private var savedPerYear: Decimal { savedAmountPerMonth * 12 }
    private var savedPerWeek: Decimal { savedAmountPerMonth * 12 / 52 }

    // Gold palette
    private let goldLight = Color(red: 1.0, green: 0.92, blue: 0.55)
    private let goldMid = Color(red: 0.95, green: 0.76, blue: 0.2)
    private let goldDark = Color(red: 0.72, green: 0.55, blue: 0.05)
    private let goldShine = Color(red: 1.0, green: 0.98, blue: 0.8)

    // Holographic rainbow tints
    private let holoBlue = Color(red: 0.4, green: 0.7, blue: 1.0)
    private let holoPink = Color(red: 1.0, green: 0.5, blue: 0.7)
    private let holoGreen = Color(red: 0.4, green: 0.95, blue: 0.6)
    private let holoPurple = Color(red: 0.7, green: 0.4, blue: 1.0)

    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 440
    private let maxTiltDegrees: CGFloat = 30

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 28) {
                    tradingCard
                        .frame(width: cardWidth, height: cardHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(cardBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SubHelpDoneButton { dismiss() }
                }
            }
        }
        .presentationBackground(cardBackground)
    }

    private var cardBackground: Color { Color(white: 0.08) }

    // MARK: - Trading Card

    private var tradingCard: some View {
        ZStack {
            // Gold base
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [goldLight, goldMid, goldDark, goldMid],
                        startPoint: UnitPoint(x: 0.5 + tiltX * 0.4, y: 0),
                        endPoint: UnitPoint(x: 0.5 - tiltX * 0.4, y: 1)
                    )
                )

            // Holographic rainbow overlay that shifts with tilt
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            holoBlue.opacity(0.3),
                            holoPink.opacity(0.2),
                            holoGreen.opacity(0.25),
                            holoPurple.opacity(0.2),
                            holoBlue.opacity(0.15)
                        ],
                        startPoint: UnitPoint(x: 0.5 + tiltX * 0.6, y: 0.5 + tiltY * 0.6),
                        endPoint: UnitPoint(x: 0.5 - tiltX * 0.6, y: 0.5 - tiltY * 0.6)
                    )
                )

            // Specular highlight that follows the tilt
            RadialGradient(
                colors: [goldShine.opacity(0.6), .clear],
                center: UnitPoint(x: 0.5 + tiltX * 0.5, y: 0.5 + tiltY * 0.5),
                startRadius: 10,
                endRadius: 220
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Card content
            VStack(spacing: 0) {
                // Mascot at the top
                Image("ShibaMascot")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [goldShine, goldMid],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: goldDark.opacity(0.4), radius: 8, y: 4)
                    .padding(.top, 28)

                Text("I'm Saving")
                    .font(.system(.caption, design: .default, weight: .bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(.black.opacity(0.5))
                    .padding(.top, 14)

                // Large yearly amount
                Text(CurrencyOptions.formatPresentation(amount: savedPerYear, currencyCode: currencyCode))
                    .font(.system(size: 36, weight: .heavy, design: .default))
                    .foregroundStyle(.black.opacity(0.9))
                    .padding(.top, 4)

                Text("per year")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(.black.opacity(0.6))
                    .padding(.top, 2)

                Spacer()

                // Monthly and weekly
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(CurrencyOptions.formatPresentation(amount: savedAmountPerMonth, currencyCode: currencyCode))
                            .font(.system(.title3, design: .default, weight: .bold))
                            .foregroundStyle(.black.opacity(0.85))
                        Text("per month")
                            .font(.system(.caption2, design: .default, weight: .medium))
                            .foregroundStyle(.black.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(.black.opacity(0.12))
                        .frame(width: 1, height: 36)

                    VStack(spacing: 4) {
                        Text(CurrencyOptions.formatPresentation(amount: savedPerWeek, currencyCode: currencyCode))
                            .font(.system(.title3, design: .default, weight: .bold))
                            .foregroundStyle(.black.opacity(0.85))
                        Text("per week")
                            .font(.system(.caption2, design: .default, weight: .medium))
                            .foregroundStyle(.black.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [goldShine, goldMid.opacity(0.6), goldShine.opacity(0.8), goldDark.opacity(0.4)],
                        startPoint: UnitPoint(x: tiltX * 0.5, y: 0),
                        endPoint: UnitPoint(x: 1 - tiltX * 0.5, y: 1)
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: goldMid.opacity(0.45), radius: 24, x: tiltX * 6, y: tiltY * 6 + 8)
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
        .rotation3DEffect(
            .degrees(Double(tiltY) * maxTiltDegrees),
            axis: (x: -1, y: 0, z: 0),
            perspective: 0.6
        )
        .rotation3DEffect(
            .degrees(Double(tiltX) * maxTiltDegrees),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.6
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    let normX = (value.location.x / cardWidth - 0.5) * 2
                    let normY = (value.location.y / cardHeight - 0.5) * 2
                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.7)) {
                        tiltX = min(max(normX, -1), 1)
                        tiltY = min(max(normY, -1), 1)
                        isDragging = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        tiltX = 0
                        tiltY = 0
                        isDragging = false
                    }
                }
        )
    }
}

private struct MainTabsPreview: View {
    @StateObject private var homeViewModel = HomeViewModel(subscriptions: HomeViewModel.sampleSubscriptions)
    @StateObject private var premiumProducts = PremiumSubscriptionProducts()

    var body: some View {
        TabView {
            Tab("Subscriptions", systemImage: "creditcard") {
                HomeView(
                    viewModel: homeViewModel,
                    subscriptionTier: .free,
                    onTierChange: { _ in }
                )
            }
            Tab("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                HistoryView(viewModel: homeViewModel)
            }
            Tab("Help", systemImage: "questionmark.circle") {
                HelpView(viewModel: homeViewModel)
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(.blue)
        .environmentObject(premiumProducts)
    }
}

#Preview {
    MainTabsPreview()
}
