import SwiftUI

// MARK: - Goal type

private enum Save100Phase {
    case enterTarget
    case thinking
    case results
}

private enum HelpGoal: CaseIterable {
    case save100
    case discount
    case removeEntertainment

    func title(currencyCode: String) -> String {
        switch self {
        case .save100: return "Save a target amount over the next year"
        case .discount: return "Get a discount on the subscriptions I already have"
        case .removeEntertainment: return "See how much I'd save if I got rid of my streaming services"
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    @ObservedObject var viewModel: HomeViewModel
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @AppStorage("subscriptionTier") private var subscriptionTierRaw: String = SubscriptionTier.free.rawValue
    @State private var selectedGoal: HelpGoal?
    @State private var showUpgradePaywall = false

    private var subscriptionTier: SubscriptionTier {
        SubscriptionTier(rawValue: subscriptionTierRaw) ?? .free
    }
    @State private var isThinking = false
    /// Amount in the text field (draft); results do not update until OK.
    @State private var saveTargetInput: Decimal = 100
    /// Amount used for combination math after the last OK / thinking step.
    @State private var saveTargetApplied: Decimal = 100
    @State private var save100Phase: Save100Phase = .enterTarget
    @State private var helpSelectedSubscription: Subscription?

    private static let streamingServiceNames: Set<String> = [
        "netflix", "disney+", "spotify", "youtube premium", "max", "hbo", "audible",
        "apple tv+", "apple music", "paramount+", "peacock", "crunchyroll", "dazn",
        "deezer", "tidal", "soundcloud", "prime video", "hulu", "espn+"
    ]

    /// Streaming savings include manually added subs with category **Streaming**, plus known services by name when category is unset (e.g. older data).
    private static func isStreamingSubscription(_ sub: Subscription) -> Bool {
        if sub.category == SubscriptionCategory.streaming.rawValue { return true }
        return streamingServiceNames.contains(sub.name.lowercased())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if subscriptionTier == .free {
                        PremiumUpgradePromoBanner(onUpgradeTap: { showUpgradePaywall = true })
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    // What do you want to achieve? (left) + dog (right)
                    HStack(alignment: .center, spacing: 16) {
                        Text("What do you want to achieve?")
                            .font(.system(.title2, design: .default, weight: .bold))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image("ShibaMascot")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, subscriptionTier == .free ? 8 : 24)

                    // Selected option label (under the header line when one is picked)
                    if let goal = selectedGoal {
                        Text(goal.title(currencyCode: currencyCode))
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, -8)
                    }

                    // Option buttons only when nothing selected yet
                    if selectedGoal == nil {
                        VStack(spacing: 12) {
                            ForEach(HelpGoal.allCases, id: \.self) { goal in
                                Button {
                                    selectedGoal = goal
                                    if goal == .save100 {
                                        save100Phase = .enterTarget
                                        isThinking = false
                                    } else {
                                        isThinking = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                            isThinking = false
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(goal.title(currencyCode: currencyCode))
                                            .font(.system(.subheadline, design: .default, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Pulsing "Thinking..." (contained) or result below
                    if isThinking {
                        thinkingView
                            .padding(.vertical, 24)
                    } else if let goal = selectedGoal {
                        goalResultContent(goal)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Help")
            .sheet(isPresented: $showUpgradePaywall) {
                UpgradePaywallView { tier in
                    subscriptionTierRaw = tier.rawValue
                }
            }
            .sheet(item: $helpSelectedSubscription) { sub in
                NavigationStack {
                    SubscriptionDetailView(
                        subscription: Binding(
                            get: { viewModel.subscriptions.first(where: { $0.id == sub.id }) ?? sub },
                            set: { viewModel.updateSubscription($0) }
                        ),
                        onUnsubscribe: { cancelled in
                            helpSelectedSubscription = nil
                            viewModel.removeSubscription(cancelled)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Pulsing thinking indicator (dot with radiating pulse, contained above text)

    private var thinkingView: some View {
        TimelineView(.animation(minimumInterval: 0.03)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let period: TimeInterval = 5.0
            VStack(spacing: 20) {
                // Pulse contained in fixed area so it doesn't overlap "Thinking..."
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        let phase = (t / period + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .strokeBorder(Color.blue.opacity(0.6 - phase * 0.6), lineWidth: 5)
                            .frame(width: 24, height: 24)
                            .scaleEffect(1 + phase * 2.2)
                    }
                    Circle()
                        .fill(.blue)
                        .frame(width: 20, height: 20)
                }
                .frame(width: 90, height: 90)
                .clipped()
                .frame(maxWidth: .infinity)

                Text("Thinking...")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Result content (below the options, same screen)

    @ViewBuilder
    private func goalResultContent(_ goal: HelpGoal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                selectedGoal = nil
                save100Phase = .enterTarget
            } label: {
                Text("Choose another goal")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 20)

            switch goal {
            case .save100:
                switch save100Phase {
                case .enterTarget:
                    save100TargetPrompt
                case .thinking:
                    thinkingView
                        .padding(.vertical, 24)
                case .results:
                    save100Content
                }
            case .discount:
                discountContent
            case .removeEntertainment:
                removeEntertainmentContent
            }
        }
    }

    // MARK: - Save target amount (confirm before thinking)

    private func runSave100Calculation() {
        save100Phase = .thinking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            saveTargetApplied = saveTargetInput
            save100Phase = .results
        }
    }

    private var save100TargetPrompt: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How much do you want to save over the next year?")
                .font(.system(.title3, design: .default, weight: .bold))
                .padding(.horizontal, 20)

            HStack {
                Text("Target amount")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                Spacer()
                TextField("Amount", value: $saveTargetInput, format: .currency(code: currencyCode))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            Button(action: runSave100Calculation) {
                Text("OK")
                    .font(.system(.body, design: .default, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Save target amount (up to 3 combinations)

    private var save100Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save over the next year")
                .font(.system(.title3, design: .default, weight: .bold))
                .padding(.horizontal, 20)

            HStack {
                Text("Target amount")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                Spacer()
                TextField("Amount", value: $saveTargetInput, format: .currency(code: currencyCode))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            Button(action: runSave100Calculation) {
                Text("OK")
                    .font(.system(.body, design: .default, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)

            // Only `saveTargetApplied` drives options below — editing the field does not recalculate until OK.
            save100AppliedResults
                .id(saveTargetApplied)
                .animation(nil, value: saveTargetApplied)
        }
    }

    @ViewBuilder
    private var save100AppliedResults: some View {
        let targetYearly = max(saveTargetApplied, 1)
        let combinations = combinationsToSave(yearlyTarget: targetYearly, from: viewModel.subscriptions)

        if combinations.isEmpty {
            Text("Add subscriptions on the Subscriptions tab, then come back. I’ll show you combinations that add up to \(targetYearly.formatted(.currency(code: currencyCode)))/year or more.")
                .font(.system(.footnote, design: .default, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        } else {
            ForEach(Array(combinations.prefix(3).enumerated()), id: \.offset) { index, subs in
                let total = yearlyTotal(for: subs)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Option \(index + 1): Cancel these to save \(total.formatted(.currency(code: currencyCode)))/year")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                    ForEach(subs) { sub in
                        Button {
                            helpSelectedSubscription = sub
                        } label: {
                            subscriptionCard(sub)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Get a discount (general steps)

    private var discountContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Get a discount on the subscriptions you already have")
                .font(.system(.title3, design: .default, weight: .bold))
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: 1, title: "Unsubscribe to get retainer offers", body: "Start cancelling — many services will offer a discount or free months to keep you.")
                stepRow(number: 2, title: "Subscribe to their newsletters", body: "Companies often send exclusive offers and promo codes to subscribers.")
                stepRow(number: 3, title: "Refer a friend", body: "Check each service’s referral or “invite a friend” page for a free month or credit.")
            }
            .padding(.horizontal, 20)
        }
    }

    private func stepRow(number: Int, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.subheadline, design: .default, weight: .semibold))
            Text(body)
                .font(.system(.footnote, design: .default, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Remove entertainment (streaming savings)

    private var removeEntertainmentContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remove entertainment subscriptions")
                .font(.system(.title3, design: .default, weight: .bold))
                .padding(.horizontal, 20)

            let streaming = viewModel.subscriptions.filter { Self.isStreamingSubscription($0) }
            let yearlySavings = streaming.reduce(Decimal.zero) { total, sub in
                total + yearlyAmount(for: sub)
            }

            if streaming.isEmpty {
                Text("You don’t have any entertainment (streaming) subscriptions listed yet. Add them on the Subscriptions tab to see how much you’d save by cancelling them.")
                    .font(.system(.footnote, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                (Text("If you remove your streaming services below, you’d save ")
                    + Text(yearlySavings, format: .currency(code: currencyCode)).fontWeight(.semibold)
                    + Text(" per year."))
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(streaming) { sub in
                        Button {
                            helpSelectedSubscription = sub
                        } label: {
                            subscriptionCard(sub)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Subscription card (same style as Subscriptions page)

    private func subscriptionCard(_ sub: Subscription) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Next payment: \(viewModel.nextPaymentString(for: sub.nextPaymentDate))")
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
        .background(sub.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Helpers

    private func yearlyAmount(for sub: Subscription) -> Decimal {
        switch sub.frequency {
        case .weekly: return sub.price * 52
        case .monthly: return sub.price * 12
        case .yearly: return sub.price
        }
    }

    private func yearlyTotal(for subs: [Subscription]) -> Decimal {
        subs.reduce(Decimal.zero) { $0 + yearlyAmount(for: $1) }
    }

    /// Returns up to 3 combinations of subscriptions whose yearly total is >= target.
    private func combinationsToSave(yearlyTarget: Decimal, from subs: [Subscription]) -> [[Subscription]] {
        let sorted = subs.sorted { yearlyAmount(for: $0) > yearlyAmount(for: $1) }
        var result: [[Subscription]] = []

        // Single subscriptions that already meet target
        for sub in sorted where yearlyAmount(for: sub) >= yearlyTarget {
            result.append([sub])
            if result.count >= 3 { return result }
        }

        // Pairs
        for i in 0..<sorted.count {
            for j in (i + 1)..<sorted.count {
                let pair = [sorted[i], sorted[j]]
                if yearlyTotal(for: pair) >= yearlyTarget && !result.contains(where: { Set($0.map(\.id)) == Set(pair.map(\.id)) }) {
                    result.append(pair)
                    if result.count >= 3 { return result }
                }
            }
        }

        // Triples
        for i in 0..<sorted.count {
            for j in (i + 1)..<sorted.count {
                for k in (j + 1)..<sorted.count {
                    let triple = [sorted[i], sorted[j], sorted[k]]
                    if yearlyTotal(for: triple) >= yearlyTarget && !result.contains(where: { Set($0.map(\.id)) == Set(triple.map(\.id)) }) {
                        result.append(triple)
                        if result.count >= 3 { return result }
                    }
                }
            }
        }

        return result
    }
}
