import Foundation

enum SubHelpAppGroup {
    static let identifier = "group.com.subhelp.app"
    static let snapshotKey = "subhelp.widget.upcomingSnapshot"
    static let widgetKind = "UpcomingPayments"
}

/// Active subscriptions the widget can turn into a 7-day payment list without opening the app.
struct WidgetSubscriptionRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var nextPaymentDate: Date
    var price: Decimal
    var frequency: String
    var isTrial: Bool
    var trialEndDate: Date?

    init(
        id: UUID,
        name: String,
        nextPaymentDate: Date,
        price: Decimal,
        frequency: String,
        isTrial: Bool = false,
        trialEndDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.nextPaymentDate = nextPaymentDate
        self.price = price
        self.frequency = frequency
        self.isTrial = isTrial
        self.trialEndDate = trialEndDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, nextPaymentDate, price, frequency, isTrial, trialEndDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nextPaymentDate = try container.decode(Date.self, forKey: .nextPaymentDate)
        frequency = try container.decode(String.self, forKey: .frequency)
        isTrial = try container.decodeIfPresent(Bool.self, forKey: .isTrial) ?? false
        trialEndDate = try container.decodeIfPresent(Date.self, forKey: .trialEndDate)
        let priceString = try container.decode(String.self, forKey: .price)
        price = Decimal(string: priceString, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(nextPaymentDate, forKey: .nextPaymentDate)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(isTrial, forKey: .isTrial)
        try container.encodeIfPresent(trialEndDate, forKey: .trialEndDate)
        try container.encode(NSDecimalNumber(decimal: price).stringValue, forKey: .price)
    }
}

struct WidgetSnapshot: Codable {
    var currencyCode: String
    var subscriptions: [WidgetSubscriptionRecord]
}

struct WidgetPayment: Identifiable, Hashable {
    var subscriptionID: UUID
    var name: String
    var date: Date
    var amount: Decimal

    var id: String {
        "\(subscriptionID.uuidString)-\(date.timeIntervalSinceReferenceDate)"
    }
}

enum WidgetSnapshotStore {
    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: SubHelpAppGroup.identifier) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: SubHelpAppGroup.snapshotKey)
        defaults.synchronize()
    }

    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: SubHelpAppGroup.identifier),
              let data = defaults.data(forKey: SubHelpAppGroup.snapshotKey) else {
            return WidgetSnapshot(currencyCode: "GBP", subscriptions: [])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetSnapshot.self, from: data))
            ?? WidgetSnapshot(currencyCode: "GBP", subscriptions: [])
    }
}

/// Payments due across seven calendar days starting on `day` (today through six days ahead).
enum UpcomingPayments {
    static let dayCount = 7

    static func due(
        subscriptions: [WidgetSubscriptionRecord],
        on day: Date,
        calendar: Calendar = .current
    ) -> [WidgetPayment] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: dayCount, to: start) else { return [] }

        var payments: [WidgetPayment] = []
        for record in subscriptions {
            if record.isTrial {
                let trialDay = calendar.startOfDay(for: record.trialEndDate ?? record.nextPaymentDate)
                if trialDay >= start && trialDay < end {
                    payments.append(
                        WidgetPayment(
                            subscriptionID: record.id,
                            name: displayName(record.name),
                            date: trialDay,
                            amount: record.price
                        )
                    )
                }
                continue
            }
            let frequency = WidgetBillingFrequency(rawValue: record.frequency) ?? .monthly
            for date in occurrenceDates(for: record, frequency: frequency, from: start, until: end, calendar: calendar) {
                payments.append(
                    WidgetPayment(
                        subscriptionID: record.id,
                        name: displayName(record.name),
                        date: date,
                        amount: record.price
                    )
                )
            }
        }

        payments.sort { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return payments
    }

    private static func displayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Subscription" : trimmed
    }

    /// `until` is exclusive. A renewal exactly seven days out waits for the next window, so a weekly plan appears once.
    private static func occurrenceDates(
        for record: WidgetSubscriptionRecord,
        frequency: WidgetBillingFrequency,
        from start: Date,
        until end: Date,
        calendar: Calendar
    ) -> [Date] {
        guard var cursor = firstOnOrAfter(record.nextPaymentDate, frequency: frequency, start: start, calendar: calendar) else {
            return []
        }

        var dates: [Date] = []
        var safety = 0
        while cursor < end && safety < 8 {
            dates.append(cursor)
            guard let next = advance(cursor, original: record.nextPaymentDate, frequency: frequency, calendar: calendar),
                  next > cursor else { break }
            cursor = next
            safety += 1
        }
        return dates
    }

    private static func firstOnOrAfter(
        _ stored: Date,
        frequency: WidgetBillingFrequency,
        start: Date,
        calendar: Calendar
    ) -> Date? {
        let storedDay = calendar.startOfDay(for: stored)
        if storedDay >= start { return storedDay }

        switch frequency {
        case .weekly:
            let days = calendar.dateComponents([.day], from: storedDay, to: start).day ?? 0
            let periods = max(1, (days + 6) / 7)
            return calendar.date(byAdding: .day, value: periods * 7, to: storedDay)
        case .monthly:
            return nextAnchoredDate(stored: stored, onOrAfter: start, yearly: false, calendar: calendar)
        case .yearly:
            return nextAnchoredDate(stored: stored, onOrAfter: start, yearly: true, calendar: calendar)
        }
    }

    private static func advance(
        _ date: Date,
        original: Date,
        frequency: WidgetBillingFrequency,
        calendar: Calendar
    ) -> Date? {
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .monthly, .yearly:
            guard let next = calendar.date(byAdding: frequency == .monthly ? .month : .year, value: 1, to: date) else {
                return nil
            }
            return nextAnchoredDate(stored: original, onOrAfter: next, yearly: frequency == .yearly, calendar: calendar)
        }
    }

    /// Keeps the original billing day (or month and day) when a stored renewal date is already in the past.
    private static func nextAnchoredDate(
        stored: Date,
        onOrAfter start: Date,
        yearly: Bool,
        calendar: Calendar
    ) -> Date? {
        let billingDay = calendar.component(.day, from: stored)
        let billingMonth = calendar.component(.month, from: stored)
        let startYear = calendar.component(.year, from: start)

        if yearly {
            for year in startYear...(startYear + 1) {
                if let candidate = clampedDate(year: year, month: billingMonth, day: billingDay, calendar: calendar),
                   candidate >= start {
                    return candidate
                }
            }
            return nil
        }

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) else {
            return nil
        }
        for offset in 0..<3 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart) else { return nil }
            let parts = calendar.dateComponents([.year, .month], from: month)
            if let candidate = clampedDate(year: parts.year, month: parts.month, day: billingDay, calendar: calendar),
               candidate >= start {
                return candidate
            }
        }
        return nil
    }

    private static func clampedDate(year: Int?, month: Int?, day: Int, calendar: Calendar) -> Date? {
        guard let year, let month,
              let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: first) else {
            return nil
        }
        let clampedDay = min(max(day, 1), range.count)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: clampedDay)) else {
            return nil
        }
        return calendar.startOfDay(for: date)
    }
}

private enum WidgetBillingFrequency: String {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}
