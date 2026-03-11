import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HomeViewModel
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.unsubscribed.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(viewModel.unsubscribed) { sub in
                                historyRow(sub)
                            }
                        } header: {
                            Text("\(viewModel.unsubscribed.count) cancelled")
                                .font(.system(.footnote, design: .default, weight: .medium))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("ShibaMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .opacity(0.5)
            Text("Nothing cancelled yet")
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Subscriptions you cancel will appear here.")
                .font(.system(.subheadline, design: .default, weight: .regular))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Row

    private func historyRow(_ sub: Subscription) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(sub.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(sub.name)
                    .font(.system(.body, design: .default, weight: .semibold))
                Text("Unsubscribed")
                    .font(.system(.caption, design: .default, weight: .regular))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(sub.price, format: .currency(code: currencyCode))
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(sub.frequency.shortLabel)
                    .font(.system(.caption, design: .default, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
