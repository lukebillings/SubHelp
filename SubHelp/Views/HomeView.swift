import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    var subscriptionTier: SubscriptionTier
    var onTierChange: (SubscriptionTier) -> Void

    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @State private var selectedSubscription: Subscription?
    @State private var showAddSheet = false
    @State private var showQuickStartGuide = false
    @State private var showSavingsCard = false
    @State private var showUpgradePaywall = false

    private var subscriptionLimit: Int {
        subscriptionTier == .free ? 3 : .max
    }

    private var canAddMore: Bool {
        viewModel.subscriptions.count < subscriptionLimit
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
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.systemGroupedBackground))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSubscriptionView { newSub in
                if canAddMore {
                    viewModel.addSubscription(newSub)
                } else {
                    showAddSheet = false
                    showUpgradePaywall = true
                }
            }
        }
        .sheet(isPresented: $showQuickStartGuide) {
            QuickStartGuideView { newSub in
                if canAddMore {
                    viewModel.addSubscription(newSub)
                } else {
                    showQuickStartGuide = false
                    showUpgradePaywall = true
                }
            }
        }
        .sheet(isPresented: $showUpgradePaywall) {
            UpgradePaywallView { tier in
                onTierChange(tier)
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
                            viewModel.updateSubscription(updated)
                        }
                    ),
                    onUnsubscribe: { cancelled in
                        viewModel.removeSubscription(cancelled)
                    }
                )
            }
        }
    }

    // MARK: - Welcome / Empty State

    private var welcomeState: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

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
                            showUpgradePaywall = true
                        }
                    } label: {
                        Label("Add Subscription", systemImage: "plus")
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
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
                            showUpgradePaywall = true
                        }
                    } label: {
                        Text("Help Find Subscriptions")
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
                .padding(.top, 40)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Subscription Spend")
                    .font(.system(.title3, design: .default, weight: .bold))
                    .foregroundStyle(.primary)

                (Text("\(viewModel.totalPerMonth, format: .currency(code: currencyCode)) ")
                    .font(.system(.title, design: .default, weight: .bold))
                 + Text("/month")
                    .font(.system(.title3, design: .default, weight: .medium))
                    .foregroundStyle(.secondary))

                (Text("\(viewModel.totalPerYear, format: .currency(code: currencyCode)) ")
                    .font(.system(.title, design: .default, weight: .bold))
                 + Text("/year")
                    .font(.system(.title3, design: .default, weight: .medium))
                    .foregroundStyle(.secondary))

                Button("+ Add Subscription") {
                    if canAddMore {
                        showAddSheet = true
                    } else {
                        showUpgradePaywall = true
                    }
                }
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 4)

                Button {
                    if canAddMore {
                        showQuickStartGuide = true
                    } else {
                        showUpgradePaywall = true
                    }
                } label: {
                    Text("Help Find Subscriptions")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showSavingsCard = true
            } label: {
                ZStack(alignment: .bottom) {
                    Image("ShibaMascot")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())

                    VStack(spacing: 2) {
                        Text(viewModel.savedAmount * 12, format: .currency(code: currencyCode))
                            .font(.system(.subheadline, design: .default, weight: .bold))
                        Text("Yearly Savings")
                            .font(.system(.caption2, design: .default, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 1.0, green: 0.84, blue: 0.0))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 2)
                    .offset(y: 20)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentShape(Rectangle())
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
        LazyVStack(spacing: 12) {
            ForEach(viewModel.subscriptionsForDisplay) { sub in
                subscriptionCard(sub)
                    .onTapGesture { selectedSubscription = sub }
            }

        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private func subscriptionCard(_ sub: Subscription) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Next payment: \(viewModel.nextPaymentString(for: sub.nextPaymentDate))")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(sub.price, format: .currency(code: currencyCode))
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(sub.frequency.shortLabel)
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sub.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Calendar

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var calendarSection: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Month navigation
                HStack {
                    Button { viewModel.changeMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(.body, design: .default, weight: .semibold))
                    }
                    Spacer()
                    Text(viewModel.monthYearString)
                        .font(.system(.headline, design: .default, weight: .bold))
                    Spacer()
                    Button { viewModel.changeMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(.body, design: .default, weight: .semibold))
                    }
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
                                        .font(.system(.body, design: .default, weight: isSelected ? .bold : .regular))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .frame(width: 28, height: 28)
                                        .background(isSelected ? Color.blue : Color.clear)
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
                            calendarCard(sub)
                                .onTapGesture { selectedSubscription = sub }
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
            Text(sub.name)
                .font(.system(.subheadline, design: .default, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(sub.price, format: .currency(code: currencyCode))
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundStyle(.white)
            Text(sub.frequency.rawValue)
                .font(.system(.caption, design: .default, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(sub.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                Color(white: 0.08).ignoresSafeArea()

                VStack(spacing: 28) {
                    tradingCard
                        .frame(width: cardWidth, height: cardHeight)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
    }

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
                Text(savedPerYear, format: .currency(code: currencyCode))
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
                        Text(savedAmountPerMonth, format: .currency(code: currencyCode))
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
                        Text(savedPerWeek, format: .currency(code: currencyCode))
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

    var body: some View {
        TabView {
            Tab("Subscriptions", systemImage: "creditcard.fill") {
                HomeView(
                    viewModel: homeViewModel,
                    subscriptionTier: .free,
                    onTierChange: { _ in }
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
    }
}

#Preview {
    MainTabsPreview()
}
