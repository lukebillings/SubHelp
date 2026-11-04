import SwiftUI
import WidgetKit

struct UpcomingEntry: TimelineEntry {
    var date: Date
    var currencyCode: String
    var payments: [WidgetPayment]

    var total: Decimal {
        payments.reduce(.zero) { $0 + $1.amount }
    }

    static func sample(on date: Date = Date()) -> UpcomingEntry {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: start) ?? start
        }
        return UpcomingEntry(
            date: date,
            currencyCode: "GBP",
            payments: [
                WidgetPayment(subscriptionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Netflix", date: day(0), amount: decimal("15.99")),
                WidgetPayment(subscriptionID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Spotify", date: day(1), amount: decimal("11.99")),
                WidgetPayment(subscriptionID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "iCloud+", date: day(4), amount: decimal("2.99"))
            ]
        )
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }
}

struct UpcomingPaymentsProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEntry {
        .sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEntry) -> Void) {
        completion(makeEntry(for: Date(), allowSample: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEntry>) -> Void) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let entries = (0..<UpcomingPayments.dayCount).compactMap { offset -> UpcomingEntry? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return makeEntry(for: day, allowSample: false)
        }
        let refresh = calendar.date(byAdding: .day, value: UpcomingPayments.dayCount, to: start)
            ?? Date().addingTimeInterval(86_400 * Double(UpcomingPayments.dayCount))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func makeEntry(for date: Date, allowSample: Bool) -> UpcomingEntry {
        let snapshot = WidgetSnapshotStore.load()
        if allowSample, snapshot.subscriptions.isEmpty {
            return .sample(on: date)
        }
        return UpcomingEntry(
            date: date,
            currencyCode: snapshot.currencyCode,
            payments: UpcomingPayments.due(subscriptions: snapshot.subscriptions, on: date)
        )
    }
}

struct UpcomingPaymentsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SubHelpAppGroup.widgetKind, provider: UpcomingPaymentsProvider()) { entry in
            UpcomingPaymentsWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming payments")
        .description("Subscription payments due in the next 7 days, and how much each one costs.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Views

private enum UpcomingWidgetStyle {
    static let gold = Color(red: 0.96, green: 0.78, blue: 0.22)
}

private enum UpcomingPaymentFormatting {
    static func amount(_ amount: Decimal, currencyCode: String) -> String {
        CurrencyOptions.formatPresentation(amount: amount, currencyCode: currencyCode)
    }

    static func countLabel(_ count: Int) -> String {
        count == 1 ? "1 payment" : "\(count) payments"
    }

    static func dayLabel(for date: Date, reference: Date, style: DayStyle) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: reference)
        let paymentDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: paymentDay).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default:
            switch style {
            case .compact:
                return date.formatted(.dateTime.weekday(.abbreviated))
            case .full:
                return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            }
        }
    }

    enum DayStyle {
        case compact
        case full
    }
}

private struct UpcomingWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                UpcomingWidgetStyle.gold.opacity(colorScheme == .dark ? 0.34 : 0.5),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct UpcomingPaymentsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: UpcomingEntry

    private var payments: [WidgetPayment] { entry.payments }

    private var totalText: String {
        UpcomingPaymentFormatting.amount(entry.total, currencyCode: entry.currencyCode)
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                background
            }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular:
            AccessoryWidgetBackground()
        default:
            if renderingMode == .accented {
                Color(.systemGroupedBackground)
            } else {
                UpcomingWidgetBackground()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            homeList(limit: 3, dayStyle: .compact)
        case .systemLarge:
            homeList(limit: 6, dayStyle: .full)
        case .systemExtraLarge:
            homeList(limit: 10, dayStyle: .full)
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            homeList(limit: 3, dayStyle: .compact)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            mark
            Text("Total due next 7 days")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(totalText)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .widgetAccentable()
            Text(UpcomingPaymentFormatting.countLabel(payments.count))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let next = payments.first {
                Text(next.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(UpcomingPaymentFormatting.dayLabel(for: next.date, reference: entry.date, style: .compact))
                    Spacer(minLength: 0)
                    Text(UpcomingPaymentFormatting.amount(next.amount, currencyCode: entry.currencyCode))
                        .widgetAccentable()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Nothing due")
                    .font(.subheadline.weight(.semibold))
                Text("No payments this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func homeList(limit: Int, dayStyle: UpcomingPaymentFormatting.DayStyle) -> some View {
        let visible = Array(payments.prefix(limit))
        let hidden = payments.count - visible.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        mark
                        Text("Total due next 7 days")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(UpcomingPaymentFormatting.countLabel(payments.count))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(totalText)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .widgetAccentable()
            }

            if payments.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing due")
                    .font(.headline)
                Text("No subscription payments in the next 7 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, payment in
                        if index > 0 {
                            Divider()
                        }
                        paymentRow(payment, dayStyle: dayStyle)
                            .padding(.vertical, 5)
                    }
                }
                if hidden > 0 {
                    Text("+\(hidden) more")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func paymentRow(_ payment: WidgetPayment, dayStyle: UpcomingPaymentFormatting.DayStyle) -> some View {
        HStack(spacing: 8) {
            Text(payment.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(UpcomingPaymentFormatting.dayLabel(for: payment.date, reference: entry.date, style: dayStyle))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(UpcomingPaymentFormatting.amount(payment.amount, currencyCode: entry.currencyCode))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .widgetAccentable()
        }
    }

    private var inline: some View {
        Label(inlineText, systemImage: "creditcard")
    }

    private var inlineText: String {
        if payments.isEmpty {
            return "No payments in 7 days"
        }
        if payments.count == 1, let payment = payments.first {
            let day = UpcomingPaymentFormatting.dayLabel(for: payment.date, reference: entry.date, style: .compact)
            let price = UpcomingPaymentFormatting.amount(payment.amount, currencyCode: entry.currencyCode)
            return "\(payment.name) \(price) \(day)"
        }
        return "\(UpcomingPaymentFormatting.countLabel(payments.count)) · \(totalText)"
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Text(totalText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.35)
                .lineLimit(1)
                .widgetAccentable()
            Text(payments.isEmpty ? "Clear" : "7 days")
                .font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 4)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Total due next 7 days")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                if !payments.isEmpty {
                    Text(totalText)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                }
            }
            if payments.isEmpty {
                Text("Nothing due")
                    .font(.caption)
            } else {
                ForEach(payments.prefix(2)) { payment in
                    HStack(spacing: 4) {
                        Text(payment.name)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(UpcomingPaymentFormatting.dayLabel(for: payment.date, reference: entry.date, style: .compact))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(UpcomingPaymentFormatting.amount(payment.amount, currencyCode: entry.currencyCode))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.medium))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mark: some View {
        Capsule()
            .fill(UpcomingWidgetStyle.gold)
            .frame(width: 18, height: 4)
            .widgetAccentable()
    }
}

#Preview(as: .systemSmall) {
    UpcomingPaymentsWidget()
} timeline: {
    UpcomingEntry.sample()
}

#Preview(as: .systemMedium) {
    UpcomingPaymentsWidget()
} timeline: {
    UpcomingEntry.sample()
}

#Preview(as: .accessoryRectangular) {
    UpcomingPaymentsWidget()
} timeline: {
    UpcomingEntry.sample()
}
