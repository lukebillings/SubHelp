import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage("notificationDaysBefore") private var notificationDaysBefore: Int = 1
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    private let topCurrencies: [(code: String, label: String)] = [
        ("USD", "$ USD – US Dollar"),
        ("EUR", "€ EUR – Euro"),
        ("GBP", "£ GBP – British Pound"),
        ("JPY", "¥ JPY – Japanese Yen"),
        ("CNY", "¥ CNY – Chinese Yuan"),
    ]

    private let otherCurrencies: [(code: String, label: String)] = [
        ("AED", "د.إ AED – UAE Dirham"),
        ("ARS", "$ ARS – Argentine Peso"),
        ("AUD", "A$ AUD – Australian Dollar"),
        ("BDT", "৳ BDT – Bangladeshi Taka"),
        ("BGN", "лв BGN – Bulgarian Lev"),
        ("BHD", "BD BHD – Bahraini Dinar"),
        ("BRL", "R$ BRL – Brazilian Real"),
        ("CAD", "CA$ CAD – Canadian Dollar"),
        ("CHF", "CHF – Swiss Franc"),
        ("CLP", "$ CLP – Chilean Peso"),
        ("COP", "$ COP – Colombian Peso"),
        ("CZK", "Kč CZK – Czech Koruna"),
        ("DKK", "kr DKK – Danish Krone"),
        ("EGP", "E£ EGP – Egyptian Pound"),
        ("HKD", "HK$ HKD – Hong Kong Dollar"),
        ("HRK", "kn HRK – Croatian Kuna"),
        ("HUF", "Ft HUF – Hungarian Forint"),
        ("IDR", "Rp IDR – Indonesian Rupiah"),
        ("ILS", "₪ ILS – Israeli Shekel"),
        ("INR", "₹ INR – Indian Rupee"),
        ("ISK", "kr ISK – Icelandic Króna"),
        ("KRW", "₩ KRW – South Korean Won"),
        ("KWD", "KD KWD – Kuwaiti Dinar"),
        ("MXN", "MX$ MXN – Mexican Peso"),
        ("MYR", "RM MYR – Malaysian Ringgit"),
        ("NGN", "₦ NGN – Nigerian Naira"),
        ("NOK", "kr NOK – Norwegian Krone"),
        ("NZD", "NZ$ NZD – New Zealand Dollar"),
        ("PEN", "S/ PEN – Peruvian Sol"),
        ("PHP", "₱ PHP – Philippine Peso"),
        ("PKR", "₨ PKR – Pakistani Rupee"),
        ("PLN", "zł PLN – Polish Złoty"),
        ("QAR", "QR QAR – Qatari Riyal"),
        ("RON", "lei RON – Romanian Leu"),
        ("RUB", "₽ RUB – Russian Ruble"),
        ("SAR", "﷼ SAR – Saudi Riyal"),
        ("SEK", "kr SEK – Swedish Krona"),
        ("SGD", "S$ SGD – Singapore Dollar"),
        ("THB", "฿ THB – Thai Baht"),
        ("TRY", "₺ TRY – Turkish Lira"),
        ("TWD", "NT$ TWD – Taiwan Dollar"),
        ("UAH", "₴ UAH – Ukrainian Hryvnia"),
        ("VND", "₫ VND – Vietnamese Dong"),
        ("ZAR", "R ZAR – South African Rand"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Currency") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(topCurrencies, id: \.code) { currency in
                            Text(currency.label).tag(currency.code)
                        }
                        Divider()
                        ForEach(otherCurrencies, id: \.code) { currency in
                            Text(currency.label).tag(currency.code)
                        }
                    }
                    .font(.system(.body, design: .default, weight: .regular))
                }

                Section("Notifications") {
                    Picker("Days before renewal", selection: $notificationDaysBefore) {
                        Text("Never").tag(-1)
                        Text("Same day").tag(0)
                        Text("1 day before").tag(1)
                        Text("2 days before").tag(2)
                        Text("3 days before").tag(3)
                        Text("1 week before").tag(7)
                    }
                    .font(.system(.body, design: .default, weight: .regular))
                }

                Section("Other") {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptics", systemImage: "hand.tap")
                    }

                    Toggle(isOn: $darkModeEnabled) {
                        Label("Dark mode", systemImage: "moon.fill")
                    }

                    Button {
                        requestAppStoreRating()
                    } label: {
                        Label("Rate", systemImage: "star.fill")
                    }

                    ShareLink(item: URL(string: "https://apps.apple.com/app/subhelp")!) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                .font(.system(.body, design: .default, weight: .regular))

                Section("Legal") {
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("Terms and Conditions", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "lock.shield")
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
        AppStore.requestReview(in: scene)
    }
}

#Preview {
    SettingsView()
}
