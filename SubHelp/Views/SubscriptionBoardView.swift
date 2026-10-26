import SwiftUI

/// Horizontal stages for sorting subscriptions. Drag a card, or use the menu, to move it.
struct SubscriptionBoardView: View {
    @ObservedObject var viewModel: HomeViewModel
    var currencyCode: String
    @Binding var selectedSubscription: Subscription?
    var cardTransition: Namespace.ID

    @State private var targetedCardID: UUID?
    @State private var targetedEndStage: SubscriptionStage?

    var body: some View {
        if viewModel.subscriptionsForDisplay.isEmpty, !viewModel.subscriptions.isEmpty {
            Text("No subscriptions in this category.")
                .font(.system(.subheadline, design: .default, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 24)
        } else {
            GeometryReader { geo in
                let columnWidth = min(300, max(240, geo.size.width * 0.78))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(SubscriptionStage.allCases) { stage in
                            column(stage, width: columnWidth, height: geo.size.height)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func column(_ stage: SubscriptionStage, width: CGFloat, height: CGFloat) -> some View {
        let cards = viewModel.subscriptions(in: stage)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(stage.rawValue)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text("\(cards.count)")
                    .font(.system(.caption, design: .default, weight: .bold))
                    .foregroundStyle(stage.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(stage.tint.opacity(0.15), in: Capsule())
            }

            ScrollView {
                VStack(spacing: 10) {
                    if cards.isEmpty {
                        Text("Drop here")
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    ForEach(cards) { sub in
                        boardCard(sub, in: stage)
                    }
                    Color.primary.opacity(0.001)
                        .frame(maxWidth: .infinity, minHeight: cards.isEmpty ? 160 : 72)
                        .dropDestination(for: String.self) { items, _ in
                            drop(items, to: stage, before: nil)
                        } isTargeted: { targeted in
                            targetedEndStage = targeted ? stage : (targetedEndStage == stage ? nil : targetedEndStage)
                        }
                }
                .frame(maxWidth: .infinity, minHeight: max(120, height - 88), alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .padding(12)
        .frame(width: width, height: height, alignment: .top)
        .subHelpPanel(cornerRadius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(targetedEndStage == stage ? stage.tint : Color.clear, lineWidth: 2)
        }
    }

    private func boardCard(_ sub: Subscription, in stage: SubscriptionStage) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                selectedSubscription = sub
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sub.name)
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(priceText(for: sub))
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.subHelpPressable)
            .accessibilityLabel("\(sub.name), \(priceText(for: sub))")
            .accessibilityActions {
                ForEach(SubscriptionStage.allCases.filter { $0 != sub.stage }) { destination in
                    Button("Move to \(destination.rawValue)") {
                        move(sub.id, to: destination, before: nil)
                    }
                }
            }

            Menu {
                ForEach(SubscriptionStage.allCases) { destination in
                    Button {
                        move(sub.id, to: destination, before: nil)
                    } label: {
                        if destination == sub.stage {
                            Label(destination.rawValue, systemImage: "checkmark")
                        } else {
                            Text(destination.rawValue)
                        }
                    }
                    .disabled(destination == sub.stage)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Move \(sub.name)")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 12)
        .subHelpColorCard(sub.color, cornerRadius: 18)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white, lineWidth: targetedCardID == sub.id ? 2 : 0)
        }
        .draggable(sub.id.uuidString) {
            VStack(alignment: .leading, spacing: 4) {
                    Text(sub.name)
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                    Text(priceText(for: sub))
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
            .frame(width: 200, alignment: .leading)
            .subHelpColorCard(sub.color, cornerRadius: 18)
        }
        .dropDestination(for: String.self) { items, _ in
            drop(items, to: stage, before: sub.id)
        } isTargeted: { targeted in
            if targeted {
                targetedCardID = sub.id
            } else if targetedCardID == sub.id {
                targetedCardID = nil
            }
        }
        .matchedTransitionSource(id: sub.id, in: cardTransition)
    }

    private func priceText(for sub: Subscription) -> String {
        CurrencyOptions.formatPresentation(amount: sub.price, currencyCode: currencyCode) + sub.frequency.shortLabel
    }

    private func move(_ id: UUID, to stage: SubscriptionStage, before beforeID: UUID?) {
        if viewModel.moveSubscription(id, to: stage, before: beforeID) {
            SubHelpHaptics.impact(.light)
        }
    }

    private func drop(_ items: [String], to stage: SubscriptionStage, before beforeID: UUID?) -> Bool {
        guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
        guard viewModel.subscriptions.contains(where: { $0.id == id }) else { return false }
        if beforeID == id { return false }
        let moved = viewModel.moveSubscription(id, to: stage, before: beforeID)
        if moved {
            SubHelpHaptics.impact(.medium)
        }
        return moved
    }
}
