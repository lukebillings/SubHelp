import SwiftUI

// MARK: - Popular service (suggested monthly price for display)

private struct PopularService: Identifiable {
    let id = UUID()
    let name: String
    let suggestedMonthlyPrice: Decimal
    let color: Color
}

// MARK: - Quick Start Guide

struct QuickStartGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"

    var onAdd: (Subscription) -> Void

    @State private var serviceToAdd: PopularService?
    @State private var addPrice: Decimal = 0
    @State private var addFrequency: BillingFrequency = .monthly
    @State private var addNextPayment = Date()

    private let popularServices: [PopularService] = [
        PopularService(name: "Netflix", suggestedMonthlyPrice: 10.99, color: Color(red: 0.89, green: 0.15, blue: 0.21)),
        PopularService(name: "Spotify", suggestedMonthlyPrice: 10.99, color: Color(red: 0.11, green: 0.84, blue: 0.38)),
        PopularService(name: "Disney+", suggestedMonthlyPrice: 7.99, color: Color(red: 0.0, green: 0.48, blue: 0.9)),
        PopularService(name: "Amazon Prime", suggestedMonthlyPrice: 8.99, color: Color(red: 0.12, green: 0.53, blue: 0.9)),
        PopularService(name: "YouTube Premium", suggestedMonthlyPrice: 12.99, color: Color(red: 0.89, green: 0.15, blue: 0.21)),
        PopularService(name: "Apple TV+", suggestedMonthlyPrice: 8.99, color: Color(red: 0.07, green: 0.07, blue: 0.07)),
        PopularService(name: "Apple Music", suggestedMonthlyPrice: 10.99, color: Color(red: 0.98, green: 0.23, blue: 0.37)),
        PopularService(name: "iCloud+", suggestedMonthlyPrice: 2.99, color: Color(red: 0.36, green: 0.70, blue: 0.97)),
        PopularService(name: "Xbox Game Pass", suggestedMonthlyPrice: 12.99, color: Color(red: 0.13, green: 0.69, blue: 0.30)),
        PopularService(name: "ChatGPT Plus", suggestedMonthlyPrice: 19.99, color: Color(red: 0.0, green: 0.68, blue: 0.58)),
        PopularService(name: "Now TV", suggestedMonthlyPrice: 9.99, color: Color(red: 0.0, green: 0.0, blue: 0.0)),
        PopularService(name: "Adobe Creative Cloud", suggestedMonthlyPrice: 54.99, color: Color(red: 0.95, green: 0.33, blue: 0.13)),
        PopularService(name: "Microsoft 365", suggestedMonthlyPrice: 5.99, color: Color(red: 0.0, green: 0.47, blue: 0.84)),
        PopularService(name: "Gym", suggestedMonthlyPrice: 29.99, color: Color(red: 0.4, green: 0.2, blue: 0.6)),
    ]

    private let emailSearchCopyText = "invoice subscription renewal"

    var body: some View {
        NavigationStack {
            List {
                // Step 1: Do you have any of these?
                Section {
                    Text("Tap any you pay for. We'll ask how often you're billed (monthly, yearly, or weekly) and the amount.")
                        .font(.system(.footnote, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    ForEach(popularServices) { service in
                        Button {
                            serviceToAdd = service
                            addPrice = service.suggestedMonthlyPrice
                            addFrequency = .monthly
                            addNextPayment = Date()
                        } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(service.color)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.name)
                                        .font(.system(.body, design: .default, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("Around \(service.suggestedMonthlyPrice, format: .currency(code: currencyCode))/month")
                                        .font(.system(.caption, design: .default, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Step 1 – Do you have any of these?")
                }

                // Step 2: Find places where you have subscriptions
                Section {
                    Text("Find where your subscriptions appear, then use **Add Subscription** on the main screen to add them manually.")
                        .font(.system(.footnote, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Step 2 – Find places where you have subscriptions")
                }

                Section("Here are places to check") {
                    // 1. Apple Subscriptions — open user's subscriptions (App Store account)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Apple Subscriptions")
                            .font(.system(.subheadline, design: .default, weight: .semibold))
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

                    // 2. Email — copy row above Mail / Gmail buttons
                    VStack(alignment: .leading, spacing: 10) {
                        Text("2. Email")
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                        Text("Search for invoices and renewal emails. Copy the text below, then open your email app and paste it into the search box.")
                            .font(.system(.caption, design: .default, weight: .regular))
                            .foregroundStyle(.secondary)

                        Button {
                            UIPasteboard.general.string = emailSearchCopyText
                        } label: {
                            HStack(spacing: 8) {
                                Text(emailSearchCopyText)
                                    .font(.system(.subheadline, design: .default, weight: .regular))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Image(systemName: "doc.on.doc")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                                Label("Mail", systemImage: "envelope.fill")
                                    .font(.system(.subheadline, design: .default, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let url = URL(string: "googlegmail://") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Gmail", systemImage: "envelope.badge.fill")
                                    .font(.system(.subheadline, design: .default, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    // 3. Banking apps
                    VStack(alignment: .leading, spacing: 6) {
                        Text("3. Banking apps")
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                        Text("Open your banking app — many have a recurring payments or subscriptions section where you can see what's going out.")
                            .font(.system(.caption, design: .default, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Quick start guide")
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

                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", value: $addPrice, format: .currency(code: currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Next payment", selection: $addNextPayment, displayedComponents: .date)
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
