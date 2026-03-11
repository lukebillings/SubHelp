import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage("notificationDaysBefore") private var notificationDaysBefore: Int = 1
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"

    private let currencies: [(code: String, label: String)] = [
        ("GBP", "£ GBP – British Pound"),
        ("USD", "$ USD – US Dollar"),
        ("EUR", "€ EUR – Euro"),
        ("CAD", "CA$ CAD – Canadian Dollar"),
        ("AUD", "A$ AUD – Australian Dollar"),
        ("JPY", "¥ JPY – Japanese Yen"),
        ("CHF", "CHF – Swiss Franc"),
        ("INR", "₹ INR – Indian Rupee"),
        ("BRL", "R$ BRL – Brazilian Real"),
        ("MXN", "MX$ MXN – Mexican Peso"),
        ("SGD", "S$ SGD – Singapore Dollar"),
        ("HKD", "HK$ HKD – Hong Kong Dollar"),
        ("NOK", "kr NOK – Norwegian Krone"),
        ("SEK", "kr SEK – Swedish Krona"),
        ("DKK", "kr DKK – Danish Krone"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Currency") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(currencies, id: \.code) { currency in
                            Text(currency.label).tag(currency.code)
                        }
                    }
                    .font(.system(.body, design: .default, weight: .regular))
                }

                Section("Notifications") {
                    Picker("Days before renewal", selection: $notificationDaysBefore) {
                        Text("Same day").tag(0)
                        Text("1 day before").tag(1)
                        Text("2 days before").tag(2)
                        Text("3 days before").tag(3)
                        Text("1 week before").tag(7)
                    }
                    .font(.system(.body, design: .default, weight: .regular))
                }

                Section("Other") {
                    Button {
                        requestAppStoreRating()
                    } label: {
                        Label("Rate", systemImage: "star.fill")
                    }

                    ShareLink(item: URL(string: "https://apps.apple.com/app/subhelp")!) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink {
                        HapticsSettingsView()
                    } label: {
                        Label("Haptics", systemImage: "hand.tap")
                    }

                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("Terms", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("Privacy", systemImage: "lock.shield")
                    }
                }
                .font(.system(.body, design: .default, weight: .regular))
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    private func requestAppStoreRating() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}

struct HapticsSettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        List {
            Toggle("Enable Haptics", isOn: $hapticsEnabled)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Haptics")
    }
}

#Preview {
    SettingsView()
}
