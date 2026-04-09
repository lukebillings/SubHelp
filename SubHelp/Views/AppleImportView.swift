import SwiftUI

// MARK: - Model

private struct AppleService: Identifiable {
    let id = UUID()
    let name: String
    let tier: String         // e.g. "Individual", "200 GB"
    let price: Decimal
    let frequency: BillingFrequency
    let color: Color

    var displayName: String { tier.isEmpty ? name : "\(name) · \(tier)" }
}

// MARK: - View

struct AppleImportView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"

    var onImport: ([Subscription]) -> Void

    // Selected service IDs
    @State private var selected: Set<UUID> = []
    // Editable renewal dates, keyed by service ID
    @State private var renewalDates: [UUID: Date] = [:]

    private let services: [AppleService] = [
        // Apple One bundles
        AppleService(name: "Apple One", tier: "Individual",  price: 19.95, frequency: .monthly, color: Color(red: 0.0,  green: 0.48, blue: 0.9)),
        AppleService(name: "Apple One", tier: "Family",      price: 24.95, frequency: .monthly, color: Color(red: 0.0,  green: 0.48, blue: 0.9)),
        AppleService(name: "Apple One", tier: "Premier",     price: 32.95, frequency: .monthly, color: Color(red: 0.0,  green: 0.48, blue: 0.9)),
        // TV+
        AppleService(name: "Apple TV+",  tier: "",           price: 8.99,  frequency: .monthly, color: Color(red: 0.07, green: 0.07, blue: 0.07)),
        // Music
        AppleService(name: "Apple Music", tier: "Individual", price: 10.99, frequency: .monthly, color: Color(red: 0.98, green: 0.23, blue: 0.37)),
        AppleService(name: "Apple Music", tier: "Family",     price: 16.99, frequency: .monthly, color: Color(red: 0.98, green: 0.23, blue: 0.37)),
        AppleService(name: "Apple Music", tier: "Student",    price: 5.99,  frequency: .monthly, color: Color(red: 0.98, green: 0.23, blue: 0.37)),
        // iCloud+
        AppleService(name: "iCloud+", tier: "50 GB",          price: 0.99,  frequency: .monthly, color: Color(red: 0.36, green: 0.70, blue: 0.97)),
        AppleService(name: "iCloud+", tier: "200 GB",         price: 2.99,  frequency: .monthly, color: Color(red: 0.36, green: 0.70, blue: 0.97)),
        AppleService(name: "iCloud+", tier: "2 TB",           price: 8.99,  frequency: .monthly, color: Color(red: 0.36, green: 0.70, blue: 0.97)),
        AppleService(name: "iCloud+", tier: "6 TB",           price: 29.99, frequency: .monthly, color: Color(red: 0.36, green: 0.70, blue: 0.97)),
        AppleService(name: "iCloud+", tier: "12 TB",          price: 59.99, frequency: .monthly, color: Color(red: 0.36, green: 0.70, blue: 0.97)),
        // Arcade
        AppleService(name: "Apple Arcade", tier: "",          price: 6.99,  frequency: .monthly, color: Color(red: 0.55, green: 0.24, blue: 0.90)),
        // News+
        AppleService(name: "Apple News+", tier: "",           price: 12.99, frequency: .monthly, color: Color(red: 0.95, green: 0.23, blue: 0.21)),
        // Fitness+
        AppleService(name: "Apple Fitness+", tier: "",        price: 9.99,  frequency: .monthly, color: Color(red: 0.25, green: 0.75, blue: 0.45)),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Apple subscriptions have been opened in Settings as a reference. Tick the ones you have below, set the renewal date, then tap Add.")
                            .font(.system(.footnote, design: .default, weight: .regular))
                            .foregroundStyle(.secondary)

                        Button {
                            if let url = URL(string: "App-prefs:APPLE_ACCOUNT&path=SUBSCRIPTIONS") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Open Apple Subscriptions", systemImage: "arrow.up.right.square")
                                .font(.system(.footnote, design: .default, weight: .medium))
                        }
                    }
                    .padding(.vertical, 4)
                }

                ForEach(services) { service in
                    serviceRow(service)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import from Apple")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Open Apple Subscriptions in Settings immediately so user
                // can see their list as a reference while filling in this sheet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if let url = URL(string: "App-prefs:APPLE_ACCOUNT&path=SUBSCRIPTIONS") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let subs = services
                            .filter { selected.contains($0.id) }
                            .enumerated()
                            .map { index, service in
                                Subscription(
                                    name: service.tier.isEmpty ? service.name : "\(service.name) \(service.tier)",
                                    nextPaymentDate: renewalDates[service.id] ?? Date(),
                                    price: service.price,
                                    color: service.color,
                                    frequency: service.frequency,
                                    addedAt: Date().addingTimeInterval(TimeInterval(index) * 0.001)
                                )
                            }
                        onImport(subs)
                        dismiss()
                    } label: {
                        Text("Add \(selected.count > 0 ? "\(selected.count)" : "")")
                            .font(.system(.body, design: .default, weight: .semibold))
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func serviceRow(_ service: AppleService) -> some View {
        let isSelected = selected.contains(service.id)

        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Colour dot
                Circle()
                    .fill(service.color)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.displayName)
                        .font(.system(.body, design: .default, weight: .semibold))
                    Text("\(CurrencyOptions.formatPresentation(amount: service.price, currencyCode: currencyCode))\(service.frequency.shortLabel)")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : Color(.tertiaryLabel))
                    .animation(.spring(response: 0.25), value: isSelected)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelected {
                    selected.remove(service.id)
                } else {
                    selected.insert(service.id)
                    if renewalDates[service.id] == nil {
                        renewalDates[service.id] = Date()
                    }
                }
            }

            // Inline date picker when selected
            if isSelected {
                Divider().padding(.leading, 26)

                DatePicker(
                    "Next renewal",
                    selection: Binding(
                        get: { renewalDates[service.id] ?? Date() },
                        set: { renewalDates[service.id] = $0 }
                    ),
                    displayedComponents: .date
                )
                .font(.system(.subheadline, design: .default, weight: .regular))
                .padding(.leading, 26)
                .padding(.top, 6)
                .padding(.bottom, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}
