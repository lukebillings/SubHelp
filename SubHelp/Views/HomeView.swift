import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            summarySection
            segmentControl

            switch viewModel.viewMode {
            case .list:
                sortBar
                ScrollView {
                    cardsList
                }
            case .calendar:
                calendarSection
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                (Text("\(viewModel.totalPerMonth, format: .currency(code: "GBP")) ")
                    .font(.system(.title, design: .default, weight: .bold))
                 + Text("/month")
                    .font(.system(.title3, design: .default, weight: .medium))
                    .foregroundStyle(.secondary))

                (Text("\(viewModel.totalPerYear, format: .currency(code: "GBP")) ")
                    .font(.system(.title3, design: .default, weight: .bold))
                 + Text("/year")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(.secondary))

                Button("+ Add Subscription") { }
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.blue)
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .bottom) {
                Image("ShibaMascot")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())

                Text("Saved \(viewModel.savedAmount, format: .currency(code: "GBP"))")
                    .font(.system(.caption2, design: .default, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 1.0, green: 0.84, blue: 0.0))
                    .clipShape(Capsule())
                    .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Segment

    private var segmentControl: some View {
        Picker("View", selection: $viewModel.viewMode) {
            ForEach(SubscriptionViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Sort

    private var sortBar: some View {
        HStack {
            Spacer()
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(viewModel.sortOption.rawValue)
                }
                .font(.system(.subheadline, design: .default, weight: .medium))
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - List

    private var cardsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.subscriptions) { sub in
                subscriptionCard(sub)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private func subscriptionCard(_ sub: Subscription) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("Next payment: \(viewModel.nextPaymentString(for: sub.nextPaymentDate))")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(sub.price, format: .currency(code: "GBP"))
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(sub.frequency.shortLabel)
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sub.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Calendar

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var calendarSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Month navigation
                HStack {
                    Button { viewModel.changeMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(.body, design: .default, weight: .semibold))
                    }
                    Spacer()
                    Text(viewModel.monthYearString)
                        .font(.system(.headline, design: .default, weight: .bold))
                    Spacer()
                    Button { viewModel.changeMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(.body, design: .default, weight: .semibold))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Weekday headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)

                // Day grid
                let totalDays = viewModel.daysInMonth(viewModel.selectedDate)
                let offset = viewModel.firstWeekdayOfMonth(viewModel.selectedDate)
                let selectedDay = Calendar.current.component(.day, from: viewModel.selectedDate)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(0..<(offset + totalDays), id: \.self) { index in
                        if index < offset {
                            Color.clear.frame(height: 52)
                        } else {
                            let day = index - offset + 1
                            let colors = viewModel.subscriptionColors(forDay: day, inMonth: viewModel.selectedDate)
                            let isSelected = day == selectedDay

                            Button {
                                let cal = Calendar.current
                                var comps = cal.dateComponents([.year, .month], from: viewModel.selectedDate)
                                comps.day = day
                                if let newDate = cal.date(from: comps) {
                                    viewModel.selectedDate = newDate
                                }
                            } label: {
                                VStack(spacing: 3) {
                                    Text("\(day)")
                                        .font(.system(.body, design: .default, weight: isSelected ? .bold : .regular))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .frame(width: 32, height: 32)
                                        .background(isSelected ? Color.blue : Color.clear)
                                        .clipShape(Circle())

                                    // Colored dots for subscriptions
                                    HStack(spacing: 3) {
                                        ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                                            Circle()
                                                .fill(color)
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                                .frame(height: 52)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12)

                // Subscriptions for selected date
                let subsForDate = viewModel.subscriptions(for: viewModel.selectedDate)

                if subsForDate.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No subscriptions due")
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(subsForDate) { sub in
                            calendarCard(sub)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func calendarCard(_ sub: Subscription) -> some View {
        VStack(spacing: 6) {
            Text(sub.name)
                .font(.system(.subheadline, design: .default, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(sub.price, format: .currency(code: "GBP"))
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundStyle(.white)
            Text(sub.frequency.rawValue)
                .font(.system(.caption, design: .default, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(sub.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    TabView {
        Tab("Subscriptions", systemImage: "diamond.fill") {
            HomeView(viewModel: HomeViewModel())
        }
        Tab("Settings", systemImage: "gearshape.fill") {
            SettingsView()
        }
    }
}
