import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            summarySection
            segmentControl

            ScrollView {
                cardsList
            }
        }
        .background(Color(.systemGroupedBackground))
    }

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

            VStack(spacing: 2) {
                Text(viewModel.savedAmount, format: .currency(code: "GBP"))
                    .font(.system(.title2, design: .default, weight: .bold))
                Text("Saved")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: 80, height: 64)
            .background(Color.yellow.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

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
            Text(sub.price, format: .currency(code: "GBP"))
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
