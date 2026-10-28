import SwiftUI

/// Shows the Upcoming payments widget on the Home Screen and Lock Screen.
struct WidgetShowcaseView: View {
    /// Onboarding draws the large title. Settings uses the navigation bar title instead.
    var showsTitle: Bool = true
    var embedsBackdrop: Bool = false

    @AppStorage("currencyCode") private var currencyCode: String = "GBP"

    private var showcase: ShowcaseContent {
        let snapshot = WidgetSnapshotStore.load()
        let due = UpcomingPayments.due(subscriptions: snapshot.subscriptions, on: Date())
        if due.isEmpty {
            return ShowcaseContent(
                payments: Self.examplePayments(),
                currencyCode: currencyCode,
                isExample: true
            )
        }
        return ShowcaseContent(
            payments: due,
            currencyCode: snapshot.currencyCode,
            isExample: false
        )
    }

    var body: some View {
        ZStack {
            if embedsBackdrop {
                SubHelpBackdrop()
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if showsTitle {
                        VStack(spacing: 12) {
                            Text("See payments before they land")
                                .font(.system(.title, design: .default, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                            Text("Upcoming payments sits on your Home Screen and Lock Screen. It lists what you’ll be charged in the next 7 days, and how much each one costs.")
                                .font(.system(.body, design: .default, weight: .regular))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Upcoming payments lists what you’ll be charged in the next 7 days, and how much each one costs.")
                            .font(.system(.body, design: .default, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if showcase.isExample {
                        Text("Example")
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                    }

                    sectionLabel("Home Screen")
                    HomeScreenWidgetMock(content: showcase)

                    sectionLabel("Lock Screen")
                    LockScreenWidgetMock(content: showcase)

                    sectionLabel("How to add it")
                    VStack(spacing: 10) {
                        instructionRow(
                            symbol: "apps.iphone",
                            title: "Home Screen",
                            body: "Touch and hold the Home Screen, tap +, then search for SubHelp and add Upcoming payments."
                        )
                        instructionRow(
                            symbol: "lock.iphone",
                            title: "Lock Screen",
                            body: "Touch and hold the Lock Screen, tap Customize, then add Upcoming payments."
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, showsTitle ? 12 : 8)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline, design: .default, weight: .semibold))
            .foregroundStyle(.primary)
    }

    private func instructionRow(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SubHelpTheme.brandGold)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                Text(body)
                    .font(.system(.caption, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .subHelpGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private static func examplePayments(on date: Date = Date()) -> [WidgetPayment] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: start) ?? start
        }
        func amount(_ value: String) -> Decimal {
            Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
        }
        return [
            WidgetPayment(subscriptionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Netflix", date: day(0), amount: amount("15.99")),
            WidgetPayment(subscriptionID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Spotify", date: day(1), amount: amount("11.99")),
            WidgetPayment(subscriptionID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "iCloud+", date: day(4), amount: amount("2.99"))
        ]
    }
}

private struct ShowcaseContent {
    var payments: [WidgetPayment]
    var currencyCode: String
    var isExample: Bool

    var total: Decimal {
        payments.reduce(.zero) { $0 + $1.amount }
    }

    var totalText: String {
        CurrencyOptions.formatPresentation(amount: total, currencyCode: currencyCode)
    }

    var countText: String {
        payments.count == 1 ? "1 payment" : "\(payments.count) payments"
    }

    var inlineText: String {
        if payments.isEmpty {
            return "No payments in 7 days"
        }
        if payments.count == 1, let payment = payments.first {
            return "\(payment.name) \(amount(payment.amount)) \(dayLabel(payment.date))"
        }
        return "\(countText) · \(totalText)"
    }

    func amount(_ amount: Decimal) -> String {
        CurrencyOptions.formatPresentation(amount: amount, currencyCode: currencyCode)
    }

    func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}

private struct HomeScreenWidgetMock: View {
    var content: ShowcaseContent

    private var visible: [WidgetPayment] {
        Array(content.payments.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(SubHelpTheme.brandGold)
                            .frame(width: 18, height: 4)
                        Text("Total due next 7 days")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(content.countText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(content.totalText)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            ForEach(Array(visible.enumerated()), id: \.element.id) { index, payment in
                if index > 0 {
                    Divider()
                }
                HStack(spacing: 8) {
                    Text(payment.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(content.dayLabel(payment.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(content.amount(payment.amount))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                }
                .padding(.vertical, 2)
            }

            if content.payments.count > visible.count {
                Text("+\(content.payments.count - visible.count) more")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background {
            LinearGradient(
                colors: [
                    SubHelpTheme.brandGold.opacity(0.55),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct LockScreenWidgetMock: View {
    var content: ShowcaseContent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Next 7 days")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
                if !content.payments.isEmpty {
                    Text(content.totalText)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }

            if content.payments.isEmpty {
                Text("Nothing due")
                    .font(.system(.subheadline, design: .default, weight: .medium))
            } else {
                ForEach(content.payments.prefix(2)) { payment in
                    HStack(spacing: 8) {
                        Text(payment.name)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(content.dayLabel(payment.date))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(content.amount(payment.amount))
                            .monospacedDigit()
                    }
                    .font(.system(.subheadline, design: .default, weight: .medium))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

#Preview("Onboarding") {
    ZStack {
        SubHelpBackdrop()
        WidgetShowcaseView()
    }
}

#Preview("Settings") {
    NavigationStack {
        WidgetShowcaseView(showsTitle: false, embedsBackdrop: true)
            .navigationTitle("Widgets")
            .navigationBarTitleDisplayMode(.inline)
    }
}
