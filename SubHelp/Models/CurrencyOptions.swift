import Foundation

enum CurrencyOptions {
    static let topCurrencies: [(code: String, label: String)] = [
        ("USD", "$ USD – US Dollar"),
        ("EUR", "€ EUR – Euro"),
        ("GBP", "£ GBP – British Pound"),
        ("JPY", "¥ JPY – Japanese Yen"),
        ("CNY", "¥ CNY – Chinese Yuan"),
    ]

    static let otherCurrencies: [(code: String, label: String)] = [
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
        ("DZD", "د.ج DZD – Algerian Dinar"),
        ("EGP", "E£ EGP – Egyptian Pound"),
        ("HKD", "HK$ HKD – Hong Kong Dollar"),
        ("HRK", "kn HRK – Croatian Kuna"),
        ("HUF", "Ft HUF – Hungarian Forint"),
        ("IDR", "Rp IDR – Indonesian Rupiah"),
        ("ILS", "₪ ILS – Israeli Shekel"),
        ("INR", "₹ INR – Indian Rupee"),
        ("IQD", "ع.د IQD – Iraqi Dinar"),
        ("ISK", "kr ISK – Icelandic Króna"),
        ("KGS", "сом KGS – Kyrgyzstani Som"),
        ("KRW", "₩ KRW – South Korean Won"),
        ("KWD", "KD KWD – Kuwaiti Dinar"),
        ("KZT", "₸ KZT – Kazakhstani Tenge"),
        ("LKR", "Rs LKR – Sri Lankan Rupee"),
        ("MAD", "د.م. MAD – Moroccan Dirham"),
        ("MNT", "₮ MNT – Mongolian Tögrög"),
        ("MXN", "MX$ MXN – Mexican Peso"),
        ("MYR", "RM MYR – Malaysian Ringgit"),
        ("NGN", "₦ NGN – Nigerian Naira"),
        ("NOK", "kr NOK – Norwegian Krone"),
        ("NPR", "रू NPR – Nepalese Rupee"),
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
        ("UZS", "soʻm UZS – Uzbekistani Som"),
        ("VND", "₫ VND – Vietnamese Dong"),
        ("ZAR", "R ZAR – South African Rand"),
    ]

    /// Formats an amount for display using the device locale. When the system would only show the ISO code (e.g. DZD), uses the same symbol text as the in-app currency picker.
    static func formatPresentation(amount: Decimal, currencyCode: String) -> String {
        let code = currencyCode.uppercased()
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = code
        nf.locale = .autoupdatingCurrent
        if let sym = inferredSymbol(for: code) {
            nf.currencySymbol = sym
        }
        let n = NSDecimalNumber(decimal: amount)
        if let s = nf.string(from: n) {
            return s
        }
        return amount.formatted(Decimal.FormatStyle.Currency.appDisplay(code: code))
    }

    /// Symbol text from the picker label (before ` CODE –`), when present.
    private static func inferredSymbol(for code: String) -> String? {
        let upper = code.uppercased()
        guard let label = (topCurrencies + otherCurrencies).first(where: { $0.code == upper })?.label else {
            return nil
        }
        let marker = " \(upper) – "
        guard let range = label.range(of: marker) else { return nil }
        let prefix = String(label[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        return prefix.isEmpty ? nil : prefix
    }
}

extension Decimal.FormatStyle.Currency {
    /// Narrow symbol (e.g. ₺) with the user’s locale — best for text fields and fallbacks.
    static func appDisplay(code: String) -> Decimal.FormatStyle.Currency {
        .currency(code: code)
            .locale(.autoupdatingCurrent)
            .presentation(.narrow)
    }
}
