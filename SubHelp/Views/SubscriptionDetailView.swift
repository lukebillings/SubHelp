import SwiftUI

struct SubscriptionDetailView: View {
    @Binding var subscription: Subscription
    @Environment(\.dismiss) private var dismiss

    private let colorOptions: [(String, Color)] = [
        ("Red", Color(red: 0.89, green: 0.15, blue: 0.21)),
        ("Orange", Color(red: 0.24, green: 0.6, blue: 0.87)),
        ("Yellow", Color(red: 0.9, green: 0.5, blue: 0.13)),
        ("Green", Color(red: 0.11, green: 0.84, blue: 0.38)),
        ("Dark Green", Color(red: 0.07, green: 0.49, blue: 0.17)),
        ("Blue", Color(red: 0.0, green: 0.48, blue: 0.9)),
        ("Light Blue", Color(red: 0.35, green: 0.78, blue: 0.98)),
        ("Purple", Color(red: 0.6, green: 0.35, blue: 0.71)),
        ("Teal", Color(red: 0.29, green: 0.65, blue: 0.55)),
        ("Pink", Color(red: 0.9, green: 0.3, blue: 0.5))
    ]

    private let topCancelServices = [
        ("Netflix", "https://help.netflix.com/en/node/407"),
        ("Spotify", "https://support.spotify.com/us/article/how-to-cancel/"),
        ("Disney+", "https://help.disneyplus.com/article/disneyplus-cancel-subscription"),
        ("Amazon Prime", "https://www.amazon.co.uk/gp/help/customer/display.html?nodeId=G6LDPN7YJHYKH2J6"),
        ("YouTube Premium", "https://support.google.com/youtube/answer/6308278"),
        ("Apple One", "https://support.apple.com/en-gb/108043"),
        ("Xbox Game Pass", "https://support.xbox.com/en-GB/help/subscriptions-billing/manage-subscriptions/cancel-subscription"),
        ("PlayStation Plus", "https://www.playstation.com/en-gb/support/store/cancel-ps-store-subscription/"),
        ("Adobe CC", "https://helpx.adobe.com/uk/manage-account/using/cancel-subscription.html"),
        ("Microsoft 365", "https://support.microsoft.com/en-gb/office/cancel-a-microsoft-365-subscription-46e2634c-c64b-4c65-94b9-2cc9c960e91b")
    ]

    var body: some View {
        NavigationStack {
            List {
                subDetailsSection
                cancellationHelpSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(subscription.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .default, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Sub Details

    private var subDetailsSection: some View {
        Section("Sub details") {
            Picker("Frequency", selection: $subscription.frequency) {
                ForEach(BillingFrequency.allCases, id: \.self) { freq in
                    Text(freq.rawValue).tag(freq)
                }
            }

            HStack {
                Text("Amount")
                Spacer()
                TextField("Price", value: $subscription.price, format: .currency(code: "GBP"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }

            DatePicker("When it renews", selection: $subscription.nextPaymentDate, displayedComponents: .date)

            VStack(alignment: .leading, spacing: 10) {
                Text("Background colour")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(colorOptions, id: \.0) { name, color in
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: subscription.color == color ? 3 : 0)
                            )
                            .shadow(color: subscription.color == color ? color.opacity(0.5) : .clear, radius: 4)
                            .onTapGesture {
                                subscription.color = color
                            }
                    }
                }
            }
        }
    }

    // MARK: - Cancellation Help

    private var cancellationHelpSection: some View {
        Section("Cancellation help") {
            // Auto cancel (Apple Subs)
            NavigationLink {
                AppleSubscriptionView()
            } label: {
                Label("Auto cancel (Apple Subs)", systemImage: "apple.logo")
            }

            // Cancel guide for top 10
            NavigationLink {
                topCancelGuideList
            } label: {
                Label("Cancel guide (top services)", systemImage: "list.number")
            }

            // General guide
            NavigationLink {
                GeneralCancelGuideView()
            } label: {
                Label("General cancel guide", systemImage: "questionmark.circle")
            }
        }
    }

    private var topCancelGuideList: some View {
        List {
            ForEach(topCancelServices, id: \.0) { name, urlString in
                if let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack {
                            Text(name)
                                .font(.system(.body, design: .default, weight: .regular))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cancel Guides")
    }
}

// MARK: - Apple Subscription View

struct AppleSubscriptionView: View {
    var body: some View {
        List {
            Section {
                Text("If you subscribed through the App Store, you can manage and cancel directly from your Apple ID settings.")
                    .font(.system(.body, design: .default, weight: .regular))
            }

            Section("Steps") {
                Label("Open the Settings app", systemImage: "1.circle.fill")
                Label("Tap your name at the top", systemImage: "2.circle.fill")
                Label("Tap Subscriptions", systemImage: "3.circle.fill")
                Label("Tap the subscription to cancel", systemImage: "4.circle.fill")
                Label("Tap Cancel Subscription", systemImage: "5.circle.fill")
            }

            Section {
                Button("Open Subscription Settings") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(.body, design: .default, weight: .semibold))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Apple Subscriptions")
    }
}

// MARK: - General Cancel Guide

struct GeneralCancelGuideView: View {
    var body: some View {
        List {
            Section("Via the service's website") {
                Label("Log in to the service's website", systemImage: "1.circle.fill")
                Label("Go to Account or Settings", systemImage: "2.circle.fill")
                Label("Look for Subscription or Billing", systemImage: "3.circle.fill")
                Label("Click Cancel / End subscription", systemImage: "4.circle.fill")
                Label("Confirm the cancellation", systemImage: "5.circle.fill")
            }

            Section("Via the App Store (Apple)") {
                Label("Settings → your name → Subscriptions", systemImage: "apple.logo")
            }

            Section("Via Google Play") {
                Label("Play Store → Menu → Subscriptions", systemImage: "play.fill")
            }

            Section("Via your bank") {
                Text("As a last resort, contact your bank to block future payments. Note: this may cause issues with the service provider.")
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Section("Tips") {
                Label("Screenshot confirmation emails", systemImage: "camera")
                Label("Check for a final billing date", systemImage: "calendar")
                Label("Look out for retention offers", systemImage: "tag")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("General Guide")
    }
}
