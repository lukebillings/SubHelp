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
                    ScrollView {
                        VStack(spacing: 0) {
                            savedHeroSection
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 20)

                            HStack {
                                Text("\(viewModel.unsubscribed.count) cancelled")
                                    .font(.system(.footnote, design: .default, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.unsubscribed) { sub in
                                    historyRow(sub)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("History")
        }
    }

    // MARK: - Saved hero (large number + subtext + mascot)

    private var savedHeroSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.unsubscribedSavedPerYear, format: .currency(code: currencyCode))
                        .font(.system(size: 42, weight: .bold, design: .default))
                        .foregroundStyle(.primary)
                    Text("That’s how much you’re saving per year thanks to the subscriptions you’ve cancelled.")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image("ShibaMascot")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Row (same style as homepage cards, greyed-out background)

    private func historyRow(_ sub: Subscription) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("Unsubscribed")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(sub.price, format: .currency(code: currencyCode))
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(sub.frequency.shortLabel)
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sub.color.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
