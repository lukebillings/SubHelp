import SwiftUI

// MARK: - Popular service (default price when adding; not shown on the list card)

private struct PopularService: Identifiable {
    /// Stable id so `sheet(item:)` and list cells don’t treat the same service as a new item on each view refresh (which cleared the category binding).
    var id: String { name }
    /// Matches `SubscriptionCategory` raw values (e.g. `"Streaming"` for Netflix).
    let category: String
    let name: String
    /// Prefills the add sheet; user can change before saving.
    let suggestedMonthlyPrice: Decimal
    let color: Color
}

private struct ServiceCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let services: [PopularService]
}

// MARK: - Quick Start Guide

private enum QuickStartTab: String, CaseIterable {
    case popular = "Popular services"
    case find = "Find subscriptions"
}

struct QuickStartGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"

    var onAdd: (Subscription) -> Void

    @State private var serviceToAdd: PopularService?
    @State private var showCopiedToast = false
    @State private var selectedTab: QuickStartTab = .popular
    @State private var selectedCategoryFilter: String? = nil
    @State private var searchText = ""

    /// Builds services so each item carries the canonical category string (matches `SubscriptionCategory.rawValue`).
    private static func makeCategory(_ name: String, _ rows: [(String, Double, Color)]) -> ServiceCategory {
        ServiceCategory(
            name: name,
            icon: SubscriptionCategory.symbolName(for: name),
            services: rows.map { PopularService(category: name, name: $0.0, suggestedMonthlyPrice: Decimal($0.1), color: $0.2) }
        )
    }

    // Grouped categories for Step 1
    private let serviceCategories: [ServiceCategory] = [
        Self.makeCategory("Streaming", [
            ("Netflix", 10.99, Color(red: 0.89, green: 0.15, blue: 0.21)),
            ("Disney+", 7.99, Color(red: 0.0, green: 0.48, blue: 0.9)),
            ("Spotify", 10.99, Color(red: 0.11, green: 0.84, blue: 0.38)),
            ("YouTube Premium", 12.99, Color(red: 0.89, green: 0.15, blue: 0.21)),
            ("Max (HBO)", 9.99, Color(red: 0.0, green: 0.47, blue: 0.84)),
            ("Audible", 7.99, Color(red: 0.98, green: 0.68, blue: 0.08)),
            ("DAZN", 19.99, Color(red: 0.0, green: 0.0, blue: 0.0)),
            ("Crunchyroll", 7.99, Color(red: 0.96, green: 0.55, blue: 0.07)),
        ]),
        Self.makeCategory("AI", [
            ("ChatGPT Plus", 19.99, Color(red: 0.0, green: 0.68, blue: 0.58)),
            ("Claude Pro", 19.99, Color(red: 0.4, green: 0.2, blue: 0.6)),
            ("Copilot Pro", 19.99, Color(red: 0.0, green: 0.47, blue: 0.84)),
            ("Gemini Advanced", 19.99, Color(red: 0.26, green: 0.52, blue: 0.96)),
            ("Perplexity Pro", 19.99, Color(red: 0.0, green: 0.0, blue: 0.0)),
        ]),
        Self.makeCategory("Gaming", [
            ("Xbox Game Pass", 12.99, Color(red: 0.13, green: 0.69, blue: 0.30)),
            ("PlayStation Plus", 6.99, Color(red: 0.0, green: 0.32, blue: 0.65)),
            ("Nintendo Switch Online", 3.49, Color(red: 0.89, green: 0.15, blue: 0.15)),
            ("EA Play", 4.99, Color(red: 0.0, green: 0.0, blue: 0.0)),
            ("Discord Nitro", 8.99, Color(red: 0.4, green: 0.45, blue: 0.98)),
        ]),
        Self.makeCategory("Ecommerce", [
            ("Amazon Prime", 8.99, Color(red: 0.12, green: 0.53, blue: 0.9)),
            ("Uber One", 5.99, Color(red: 0.0, green: 0.0, blue: 0.0)),
        ]),
        Self.makeCategory("Home", [
            ("Ring Protect", 3.99, Color(red: 0.0, green: 0.48, blue: 0.9)),
            ("Nest Aware", 6.00, Color(red: 0.26, green: 0.52, blue: 0.96)),
        ]),
        Self.makeCategory("Cloud & storage", [
            ("Google One", 1.99, Color(red: 0.26, green: 0.52, blue: 0.96)),
            ("Dropbox", 9.99, Color(red: 0.0, green: 0.47, blue: 0.95)),
        ]),
        Self.makeCategory("Productivity", [
            ("Microsoft 365", 5.99, Color(red: 0.0, green: 0.47, blue: 0.84)),
            ("Adobe Creative Cloud", 54.99, Color(red: 0.95, green: 0.33, blue: 0.13)),
            ("Notion", 8.99, Color(red: 0.0, green: 0.0, blue: 0.0)),
            ("Grammarly Premium", 12.99, Color(red: 0.27, green: 0.69, blue: 0.56)),
            ("Canva Pro", 10.99, Color(red: 0.2, green: 0.35, blue: 0.98)),
            ("Zoom", 12.99, Color(red: 0.27, green: 0.56, blue: 0.98)),
            ("Evernote", 7.99, Color(red: 0.13, green: 0.59, blue: 0.95)),
        ]),
        Self.makeCategory("Health", [
            ("Headspace", 9.99, Color(red: 0.96, green: 0.6, blue: 0.2)),
            ("Calm (Premium)", 9.99, Color(red: 0.15, green: 0.32, blue: 0.55)),
            ("MyFitnessPal Premium", 7.99, Color(red: 0.0, green: 0.6, blue: 0.4)),
            ("Strava", 5.99, Color(red: 0.94, green: 0.33, blue: 0.13)),
        ]),
        Self.makeCategory("Learning", [
            ("Duolingo Plus", 6.99, Color(red: 0.0, green: 0.82, blue: 0.52)),
            ("LinkedIn Premium", 29.99, Color(red: 0.0, green: 0.47, blue: 0.71)),
            ("Kindle Unlimited", 9.99, Color(red: 0.0, green: 0.48, blue: 0.0)),
            ("Coursera", 49.00, Color(red: 0.0, green: 0.45, blue: 0.74)),
        ]),
    ]

    private let emailSearchCopyText = "invoice subscription renewal"

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Category matches when a word in its name starts with the query, so “st” finds Streaming and “a” does not.
    private func categoryMatchesQuery(_ category: String) -> Bool {
        let query = searchQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !query.isEmpty else { return false }
        return category.split { !$0.isLetter && !$0.isNumber }.contains { word in
            String(word)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .hasPrefix(query)
        }
    }

    private func visibleServices(in category: ServiceCategory) -> [PopularService] {
        guard !searchQuery.isEmpty else { return category.services }
        if categoryMatchesQuery(category.name) { return category.services }
        return category.services.filter { $0.name.localizedStandardContains(searchQuery) }
    }

    private var filteredCategories: [ServiceCategory] {
        let scoped: [ServiceCategory]
        if let name = selectedCategoryFilter {
            scoped = serviceCategories.filter { $0.name == name }
        } else {
            scoped = serviceCategories
        }
        return scoped.filter { !visibleServices(in: $0).isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                // Tab selector – minimal top padding so it sits higher
                Section {
                    Picker("", selection: $selectedTab) {
                        ForEach(QuickStartTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))

                if selectedTab == .popular {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search services", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear search")
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    // Category filter pills – first, so cards sit underneath
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button {
                                    selectedCategoryFilter = nil
                                } label: {
                                    Text("All")
                                        .font(.system(.subheadline, design: .default, weight: .medium))
                                        .foregroundStyle(selectedCategoryFilter == nil ? .white : .primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .subHelpGlass(in: Capsule(), tint: selectedCategoryFilter == nil ? .blue : nil, interactive: true)
                                }
                                .buttonStyle(.plain)

                                ForEach(serviceCategories) { category in
                                    Button {
                                        selectedCategoryFilter = category.name
                                    } label: {
                                        Text(category.name)
                                            .font(.system(.subheadline, design: .default, weight: .medium))
                                            .foregroundStyle(selectedCategoryFilter == category.name ? .white : .primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .subHelpGlass(in: Capsule(), tint: selectedCategoryFilter == category.name ? .blue : nil, interactive: true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                            .animation(SubHelpTheme.snappy, value: selectedCategoryFilter)
                        }
                        .frame(height: 44)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .listRowBackground(Color.clear)
                    }

                    // Intro paragraph – under pills, above cards
                    if searchQuery.isEmpty {
                        Section {
                            Text("Here are some common subscriptions you might already have. Just tap any you use to quickly add it.")
                                .font(.system(.footnote, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listRowInsets(EdgeInsets(top: 1, leading: 16, bottom: 1, trailing: 16))
                    } else if filteredCategories.isEmpty {
                        Section {
                            Text("No services match “\(searchQuery)”.")
                                .font(.system(.footnote, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listRowInsets(EdgeInsets(top: 1, leading: 16, bottom: 1, trailing: 16))
                    }

                    // Popular services cards – underneath pills
                    ForEach(filteredCategories) { category in
                        let services = visibleServices(in: category)
                        Section {
                            ForEach(services) { service in
                                Button {
                                    serviceToAdd = service
                                } label: {
                                    HStack(spacing: 12) {
                                        SubscriptionCategoryMark(category: service.category)
                                        Text(service.name)
                                            .font(.system(.headline, design: .default, weight: .bold))
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                    .padding(18)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .subHelpColorCard(service.color)
                                }
                                .buttonStyle(.subHelpPressable)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        } header: {
                            Label(category.name, systemImage: category.icon)
                                .font(.system(.subheadline, design: .default, weight: .semibold))
                        }
                    }
                } else {
                    // Step 2: Find places where you have subscriptions
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Find where your subscriptions appear, then use the button on the main screen to add them manually.")
                                .font(.system(.footnote, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)

                            Text("+ Add Subscription")
                                .font(.system(.subheadline, design: .default, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .subHelpGlass(in: Capsule(), tint: .blue)
                        }
                        .listRowBackground(Color.clear)
                    }

                    Section("Here are places to check") {
                        // 1. Apple Subscriptions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Apple Subscriptions")
                                .font(.system(.headline, design: .default, weight: .semibold))
                            Text("See what you're billed for through your Apple ID.")
                                .font(.system(.caption, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                            Button {
                                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Open your Apple Subscriptions", systemImage: "arrow.up.right.square")
                                    .font(.system(.subheadline, design: .default, weight: .medium))
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                        // 2. Email
                        VStack(alignment: .leading, spacing: 10) {
                            Text("2. Email")
                                .font(.system(.headline, design: .default, weight: .semibold))
                            Text("Copy the text below. Open your email app with the links below, paste in the search term, then look through your mail to see subscriptions.")
                                .font(.system(.caption, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)

                            Button {
                                UIPasteboard.general.string = emailSearchCopyText
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCopiedToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showCopiedToast = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(emailSearchCopyText)
                                        .font(.system(.subheadline, design: .default, weight: .regular))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    if showCopiedToast {
                                        Label("Copied", systemImage: "checkmark.circle.fill")
                                            .font(.system(.caption, design: .default, weight: .semibold))
                                            .foregroundStyle(.green)
                                            .transition(.opacity.combined(with: .scale))
                                    } else {
                                        Image(systemName: "doc.on.doc")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .transition(.opacity)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)

                        HStack(spacing: 12) {
                                Button {
                                    if let url = URL(string: "message://") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                Text("Mail")
                                    .font(.system(.subheadline, design: .default, weight: .medium))
                                    .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    if let url = URL(string: "googlegmail://") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                Text("Gmail")
                                    .font(.system(.subheadline, design: .default, weight: .medium))
                                    .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    if let url = URL(string: "ms-outlook://") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                Text("Outlook")
                                    .font(.system(.subheadline, design: .default, weight: .medium))
                                    .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                        // 3. Banking apps
                        VStack(alignment: .leading, spacing: 6) {
                            Text("3. Banking apps")
                                .font(.system(.headline, design: .default, weight: .semibold))
                            Text("Flick through your banking app and see if you spot something you subscribe to. Many banking apps also have a recurring payments or subscriptions section — check there too.")
                                .font(.system(.caption, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .symbolRenderingMode(.hierarchical)
            .listSectionSpacing(.compact)
            .navigationTitle("Help Find Subscriptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SubHelpDoneButton { dismiss() }
                }
            }
            .sheet(item: $serviceToAdd) { service in
                AddPopularServiceSheetContent(
                    service: service,
                    currencyCode: currencyCode,
                    onAdd: { sub in
                        onAdd(sub)
                        serviceToAdd = nil
                    },
                    onDismiss: { serviceToAdd = nil }
                )
                .id(service.id)
            }
        }
    }
}

// MARK: - Add popular service sheet (local @State so category matches on first frame)

private struct AddPopularServiceSheetContent: View {
    let service: PopularService
    let currencyCode: String
    let onAdd: (Subscription) -> Void
    let onDismiss: () -> Void

    @State private var category: String
    @State private var addPrice: Decimal?
    @State private var addFrequency: BillingFrequency
    @State private var addNextPayment: Date
    @State private var isTrial: Bool
    @State private var trialEndDate: Date

    private var canAdd: Bool {
        (addPrice ?? 0) > 0
    }

    init(service: PopularService, currencyCode: String, onAdd: @escaping (Subscription) -> Void, onDismiss: @escaping () -> Void) {
        self.service = service
        self.currencyCode = currencyCode
        self.onAdd = onAdd
        self.onDismiss = onDismiss
        let cal = Calendar.current
        let nextMonth = cal.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        let comps = cal.dateComponents([.year, .month], from: nextMonth)
        let defaultNext = cal.date(from: comps) ?? Date()
        let startingCategory = SubscriptionCategory(rawValue: service.category)?.rawValue
            ?? SubscriptionCategory.other.rawValue
        _category = State(initialValue: startingCategory)
        _addPrice = State(initialValue: nil)
        _addFrequency = State(initialValue: .monthly)
        _addNextPayment = State(initialValue: defaultNext)
        _isTrial = State(initialValue: false)
        _trialEndDate = State(initialValue: cal.date(byAdding: .day, value: 7, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Service")
                        Spacer()
                        Text(service.name)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Category", selection: $category) {
                        ForEach(SubscriptionCategory.allNames, id: \.self) { cat in
                            Label(cat, systemImage: SubscriptionCategory.symbolName(for: cat)).tag(cat)
                        }
                    }

                    Picker("How do you pay?", selection: $addFrequency) {
                        ForEach(BillingFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Amount")
                            Spacer()
                            CurrencyAmountField(placeholder: "0.00", amount: $addPrice, currencyCode: currencyCode)
                        }
                        Text("How much do you pay? If not estimate.")
                            .font(.system(.caption, design: .default, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Currently on free trial", isOn: $isTrial)

                    if isTrial {
                        VStack(alignment: .leading, spacing: 6) {
                            DatePicker("Trial ends", selection: $trialEndDate, displayedComponents: .date)
                            Text("You'll get a reminder before this date. On the day, SubHelp asks if you cancelled or kept it.")
                                .font(.system(.caption, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            DatePicker("Next payment", selection: $addNextPayment, displayedComponents: .date)
                            Text("Know when your next payment is? If not we will assume 1st of each month, you can always change later.")
                                .font(.system(.caption, design: .default, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add \(service.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SubHelpCancelButton(action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SubHelpDoneButton(title: "Add") {
                        guard let price = addPrice, price > 0 else { return }
                        let sub = Subscription(
                            name: service.name,
                            nextPaymentDate: isTrial ? trialEndDate : addNextPayment,
                            price: price,
                            color: service.color,
                            frequency: addFrequency,
                            category: category,
                            isTrial: isTrial,
                            trialEndDate: isTrial ? trialEndDate : nil
                        )
                        onAdd(sub)
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}

