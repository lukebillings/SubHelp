import SwiftUI

/// Horizontal stages for sorting subscriptions. Drag a card, or use the menu, to move it.
struct SubscriptionBoardView: View {
    @ObservedObject var viewModel: HomeViewModel
    var currencyCode: String
    @Binding var selectedSubscription: Subscription?
    var cardTransition: Namespace.ID

    @State private var targetedCardID: UUID?
    @State private var targetedEndStage: SubscriptionStage?
    @State private var targetedCancelled = false

    private var cancelledCards: [Subscription] {
        viewModel.unsubscribedForDisplay
    }

    var body: some View {
        let nothingVisible = viewModel.subscriptionsForDisplay.isEmpty && cancelledCards.isEmpty
        let hasSubscriptions = !viewModel.subscriptions.isEmpty || !viewModel.unsubscribed.isEmpty
        if nothingVisible, hasSubscriptions {
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
                        cancelledColumn(width: columnWidth, height: geo.size.height)
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(stage.rawValue)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(columnTotalText(for: cards))
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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

    private func cancelledColumn(width: CGFloat, height: CGFloat) -> some View {
        let cards = cancelledCards
        let tint = Color.green
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Cancelled")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(columnTotalText(for: cards))
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 4)
                Text("\(cards.count)")
                    .font(.system(.caption, design: .default, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.15), in: Capsule())
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
                        boardCard(sub, in: nil)
                    }
                    Color.primary.opacity(0.001)
                        .frame(maxWidth: .infinity, minHeight: cards.isEmpty ? 160 : 72)
                        .dropDestination(for: String.self) { items, _ in
                            cancelDropped(items)
                        } isTargeted: { targeted in
                            targetedCancelled = targeted
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
                .strokeBorder(targetedCancelled ? tint : Color.clear, lineWidth: 2)
        }
    }

    private func boardCard(_ sub: Subscription, in stage: SubscriptionStage) -> some View {
        boardCard(sub, in: Optional(stage))
    }

    private func boardCard(_ sub: Subscription, in stage: SubscriptionStage?) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                selectedSubscription = sub
            }             label: {
                HStack(alignment: .center, spacing: 8) {
                    SubscriptionCategoryMark(category: sub.category, size: 28)
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.subHelpPressable)
            .accessibilityLabel("\(sub.name), \(priceText(for: sub))")
            .accessibilityActions {
                ForEach(SubscriptionStage.allCases.filter { stage == nil || $0 != sub.stage }) { destination in
                    Button("Move to \(destination.rawValue)") {
                        move(sub.id, to: destination, before: nil)
                    }
                }
                if stage != nil {
                    Button("Mark as cancelled") {
                        cancel(sub)
                    }
                }
            }

            Menu {
                ForEach(SubscriptionStage.allCases) { destination in
                    let isCurrent = stage != nil && destination == sub.stage
                    Button {
                        move(sub.id, to: destination, before: nil)
                    } label: {
                        if isCurrent {
                            Label(destination.rawValue, systemImage: "checkmark")
                        } else {
                            Text(destination.rawValue)
                        }
                    }
                    .disabled(isCurrent)
                }
                Divider()
                Button {
                    cancel(sub)
                } label: {
                    if stage == nil {
                        Label("Cancelled", systemImage: "checkmark")
                    } else {
                        Text("Cancelled")
                    }
                }
                .disabled(stage == nil)
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
            HStack(alignment: .center, spacing: 8) {
                SubscriptionCategoryMark(category: sub.category, size: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(sub.name)
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                    Text(priceText(for: sub))
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(12)
            .frame(width: 200, alignment: .leading)
            .subHelpColorCard(sub.color, cornerRadius: 18)
        }
        .dropDestination(for: String.self) { items, _ in
            if let stage {
                return drop(items, to: stage, before: sub.id)
            }
            return cancelDropped(items)
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

    /// Monthly total for this column, so weekly and yearly prices can be added together.
    private func columnTotalText(for cards: [Subscription]) -> String {
        let monthly = cards.reduce(Decimal.zero) { total, sub in
            total + sub.frequency.monthlyAmount(for: sub.price)
        }
        return CurrencyOptions.formatPresentation(amount: monthly, currencyCode: currencyCode) + "/mo"
    }

    private func move(_ id: UUID, to stage: SubscriptionStage, before beforeID: UUID?) {
        if viewModel.unsubscribed.contains(where: { $0.id == id }) {
            if viewModel.restoreSubscription(id, to: stage, before: beforeID) {
                SubHelpHaptics.impact(.light)
            }
            return
        }
        if viewModel.moveSubscription(id, to: stage, before: beforeID) {
            SubHelpHaptics.impact(.light)
        }
    }

    private func drop(_ items: [String], to stage: SubscriptionStage, before beforeID: UUID?) -> Bool {
        guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
        if beforeID == id { return false }
        if viewModel.unsubscribed.contains(where: { $0.id == id }) {
            let restored = viewModel.restoreSubscription(id, to: stage, before: beforeID)
            if restored {
                SubHelpHaptics.impact(.medium)
            }
            return restored
        }
        guard viewModel.subscriptions.contains(where: { $0.id == id }) else { return false }
        let moved = viewModel.moveSubscription(id, to: stage, before: beforeID)
        if moved {
            SubHelpHaptics.impact(.medium)
        }
        return moved
    }

    private func cancel(_ sub: Subscription) {
        viewModel.removeSubscription(sub)
        SubHelpHaptics.impact(.medium)
    }

    private func cancelDropped(_ items: [String]) -> Bool {
        guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
        guard let sub = viewModel.subscriptions.first(where: { $0.id == id }) else { return false }
        cancel(sub)
        return true
    }
}
