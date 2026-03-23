import SwiftUI

// MARK: - Popular service (suggested monthly price for display)

private struct PopularService: Identifiable {
    let id = UUID()
    let name: String
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
    @State private var addPrice: Decimal = 0
    @State private var addFrequency: BillingFrequency = .monthly
    @State private var addNextPayment = Date()
    @State private var showCopiedToast = false
    @State private var selectedTab: QuickStartTab = .popular
    @State private var selectedCategoryFilter: String? = nil

    // Grouped categories for Step 1
    private let serviceCategories: [ServiceCategory] = [
        ServiceCategory(name: "Streaming", icon: "play.tv", services: [
            PopularService(name: "Netflix", suggestedMonthlyPrice: 10.99, color: Color(red: 0.89, green: 0.15, blue: 0.21)),
            PopularService(name: "Disney+", suggestedMonthlyPrice: 7.99, color: Color(red: 0.0, green: 0.48, blue: 0.9)),
            PopularService(name: "Spotify", suggestedMonthlyPrice: 10.99, color: Color(red: 0.11, green: 0.84, blue: 0.38)),
            PopularService(name: "YouTube Premium", suggestedMonthlyPrice: 12.99, color: Color(red: 0.89, green: 0.15, blue: 0.21)),
            PopularService(name: "Max (HBO)", suggestedMonthlyPrice: 9.99, color: Color(red: 0.0, green: 0.47, blue: 0.84)),
            PopularService(name: "Audible", suggestedMonthlyPrice: 7.99, color: Color(red: 0.98, green: 0.68, blue: 0.08)),
            PopularService(name: "DAZN", suggestedMonthlyPrice: 19.99, color: Color(red: 0.0, green: 0.0, blue: 0.0)),
            PopularService(name: "Crunchyroll", suggestedMonthlyPrice: 7.99, color: Color(red: 0.96, green: 0.55, blue: 0.07)),
        ]),
        ServiceCategory(name: "AI", icon: "brain", services: [
            PopularService(name: "ChatGPT Plus", suggestedMonthlyPrice: 19.99, color: Color(red: 0.0, green: 0.68, blue: 0.58)),
            PopularService(name: "Claude Pro", suggestedMonthlyPrice: 19.99, color: Color(red: 0.4, green: 0.2, blue: 0.6)),
            PopularService(name: "Copilot Pro", suggestedMonthlyPrice: 19.99, color: Color(red: 0.0, green: 0.47, blue: 0.84)),
            PopularService(name: "Gemini Advanced", suggestedMonthlyPrice: 19.99, color: Color(red: 0.26, green: 0.52, blue: 0.96)),
            PopularService(name: "Perplexity Pro", suggestedMonthlyPrice: 19.99, color: Color(red: 0.0, green: 0.0, blue: 0.0)),
        ]),
        ServiceCategory(name: "Gaming", icon: "gamecontroller", services: [
            PopularService(name: "Xbox Game Pass", suggestedMonthlyPrice: 12.99, color: Color(red: 0.13, green: 0.69, blue: 0.30)),
            PopularService(name: "PlayStation Plus", suggestedMonthlyPrice: 6.99, color: Color(red: 0.0, green: 0.32, blue: 0.65)),
            PopularService(name: "Nintendo Switch Online", suggestedMonthlyPrice: 3.49, color: Color(red: 0.89, green: 0.15, blue: 0.15)),
            PopularService(name: "EA Play", suggestedMonthlyPrice: 4.99, color: Color(red: 0.0, green: 0.0, blue: 0.0)),
            PopularService(name: "Discord Nitro", suggestedMonthlyPrice: 8.99, color: Color(red: 0.4, green: 0.45, blue: 0.98)),
        ]),
        ServiceCategory(name: "Ecommerce", icon: "cart", services: [
            PopularService(name: "Amazon Prime", suggestedMonthlyPrice: 8.99, color: Color(red: 0.12, green: 0.53, blue: 0.9)),
            PopularService(name: "Uber One", suggestedMonthlyPrice: 5.99, color: Color(red: 0.0, green: 0.0, blue: 0.0)),
        ]),
        ServiceCategory(name: "Home", icon: "house", services: [
            PopularService(name: "Ring Protect", suggestedMonthlyPrice: 3.99, color: Color(red: 0.0, green: 0.48, blue: 0.9)),
            PopularService(name: "Nest Aware", suggestedMonthlyPrice: 6.00, color: Color(red: 0.26, green: 0.52, blue: 0.96)),
        ]),
        ServiceCategory(name: "Cloud & storage", icon: "externaldrive", services: [
            PopularService(name: "Google One", suggestedMonthlyPrice: 1.99, color: Color(red: 0.26, green: 0.52, blue: 0.96)),
            PopularService(name: "Dropbox", suggestedMonthlyPrice: 9.99, color: Color(red: 0.0, green: 0.47, blue: 0.95)),
        ]),
        ServiceCategory(name: "Productivity", icon: "briefcase", services: [
            PopularService(name: "Microsoft 365", suggestedMonthlyPrice: 5.99, color: Color(red: 0.0, green: 0.47, blue: 0.84)),
            PopularService(name: "Adobe Creative Cloud", suggestedMonthlyPrice: 54.99, color: Color(red: 0.95, green: 0.33, blue: 0.13)),
            PopularService(name: "Notion", suggestedMonthlyPrice: 8.99, color: Color(red: 0.0, green: 0.0, blue: 0.0)),
            PopularService(name: "Grammarly Premium", suggestedMonthlyPrice: 12.99, color: Color(red: 0.27, green: 0.69, blue: 0.56)),
            PopularService(name: "Canva Pro", suggestedMonthlyPrice: 10.99, color: Color(red: 0.2, green: 0.35, blue: 0.98)),
            PopularService(name: "Zoom", suggestedMonthlyPrice: 12.99, color: Color(red: 0.27, green: 0.56, blue: 0.98)),
            PopularService(name: "Evernote", suggestedMonthlyPrice: 7.99, color: Color(red: 0.13, green: 0.59, blue: 0.95)),
        ]),
        ServiceCategory(name: "Health", icon: "heart", services: [
            PopularService(name: "Headspace", suggestedMonthlyPrice: 9.99, color: Color(red: 0.96, green: 0.6, blue: 0.2)),
            PopularService(name: "Calm (Premium)", suggestedMonthlyPrice: 9.99, color: Color(red: 0.15, green: 0.32, blue: 0.55)),
            PopularService(name: "MyFitnessPal Premium", suggestedMonthlyPrice: 7.99, color: Color(red: 0.0, green: 0.6, blue: 0.4)),
            PopularService(name: "Strava", suggestedMonthlyPrice: 5.99, color: Color(red: 0.94, green: 0.33, blue: 0.13)),
        ]),
        ServiceCategory(name: "Learning", icon: "book", services: [
            PopularService(name: "Duolingo Plus", suggestedMonthlyPrice: 6.99, color: Color(red: 0.0, green: 0.82, blue: 0.52)),
            PopularService(name: "LinkedIn Premium", suggestedMonthlyPrice: 29.99, color: Color(red: 0.0, green: 0.47, blue: 0.71)),
            PopularService(name: "Kindle Unlimited", suggestedMonthlyPrice: 9.99, color: Color(red: 0.0, green: 0.48, blue: 0.0)),
            PopularService(name: "Coursera", suggestedMonthlyPrice: 49.00, color: Color(red: 0.0, green: 0.45, blue: 0.74)),
        ]),
    ]

    private let emailSearchCopyText = "invoice subscription renewal"

    private var filteredCategories: [ServiceCategory] {
        guard let name = selectedCategoryFilter else { return serviceCategories }
        return serviceCategories.filter { $0.name == name }
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
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedCategoryFilter == nil ? Color.blue : Color(.secondarySystemGroupedBackground))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                ForEach(serviceCategories) { category in
                                    Button {
                                        selectedCategoryFilter = category.name
                                    } label: {
                                        Text(category.name)
                                            .font(.system(.subheadline, design: .default, weight: .medium))
                                            .foregroundStyle(selectedCategoryFilter == category.name ? .white : .primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(selectedCategoryFilter == category.name ? Color.blue : Color(.secondarySystemGroupedBackground))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(height: 40)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .listRowBackground(Color.clear)
                    }

                    // Intro paragraph – under pills, above cards
                    Section {
                        Text("Here are some common subscriptions you might already have. Just tap any you use to quickly add it.")
                            .font(.system(.footnote, design: .default, weight: .regular))
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 16, bottom: 1, trailing: 16))

                    // Popular services cards – underneath pills
                    ForEach(filteredCategories) { category in
                        Section {
                            ForEach(Array(category.services.enumerated()), id: \.element.id) { index, service in
                                Button {
                                    serviceToAdd = service
                                    addPrice = service.suggestedMonthlyPrice
                                    addFrequency = .monthly

                                    let cal = Calendar.current
                                    let nextMonth = cal.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                                    let comps = cal.dateComponents([.year, .month], from: nextMonth)
                                    addNextPayment = cal.date(from: comps) ?? Date()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(service.name)
                                                .font(.system(.headline, design: .default, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text("Around \(service.suggestedMonthlyPrice, format: .currency(code: currencyCode))/month")
                                                .font(.system(.subheadline, design: .default, weight: .regular))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(service.color)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }
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
                                .padding(.vertical, 7)
                                .background(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                        .lineLimit(1)
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
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .listSectionSpacing(.compact)
            .navigationTitle("Help Find Subscriptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $serviceToAdd) { service in
                addPopularServiceSheet(service)
            }
        }
    }

    @ViewBuilder
    private func addPopularServiceSheet(_ service: PopularService) -> some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Service")
                        Spacer()
                        Text(service.name)
                            .foregroundStyle(.secondary)
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
                            TextField("0.00", value: $addPrice, format: .currency(code: currencyCode))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Text("Know how much you usually pay? If not we will estimate.")
                            .font(.system(.caption, design: .default, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        DatePicker("Next payment", selection: $addNextPayment, displayedComponents: .date)
                        Text("Know when your next payment is? If not we will assume 1st of each month, you can always change later.")
                            .font(.system(.caption, design: .default, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add \(service.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { serviceToAdd = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let sub = Subscription(
                            name: service.name,
                            nextPaymentDate: addNextPayment,
                            price: addPrice,
                            color: service.color,
                            frequency: addFrequency
                        )
                        onAdd(sub)
                        serviceToAdd = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

