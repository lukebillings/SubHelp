import SwiftUI

// MARK: - Goal type

private enum Save100Phase {
    case enterTarget
    case thinking
    case results
}

private enum CategorySavingsPhase {
    case pickCategory
    case thinking
    case results
}

private enum HelpGoal: CaseIterable {
    case save100
    case discount
    case categorySavings

    func title(currencyCode: String) -> String {
        switch self {
        case .save100: return "Save a target amount over the next year"
        case .discount: return "Get a discount on the subscriptions I already have"
        case .categorySavings: return "See how much I'd save if I got rid of a category"
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    @ObservedObject var viewModel: HomeViewModel
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @State private var selectedGoal: HelpGoal?
    @State private var isThinking = false
    /// Amount in the text field (draft); results do not update until OK.
    @State private var saveTargetInput: Decimal = 100
    /// Amount used for combination math after the last OK / thinking step.
    @State private var saveTargetApplied: Decimal = 100
    @State private var save100Phase: Save100Phase = .enterTarget
    @State private var helpSelectedSubscription: Subscription?
    /// Step for “see how much I’d save”: pick one of their categories, then show the yearly total.
    @State private var categorySavingsPhase: CategorySavingsPhase = .pickCategory
    /// Category name chosen from the ones they actually have.
    @State private var savingsCategoryName: String?

    private static let streamingServiceNames: Set<String> = [
        "netflix", "disney+", "spotify", "youtube premium", "max", "hbo", "audible",
        "apple tv+", "apple music", "paramount+", "peacock", "crunchyroll", "dazn",
        "deezer", "tidal", "soundcloud", "prime video", "hulu", "espn+"
    ]

    /// Streaming still matches known service names when category is unset (older data). Other categories match the stored category only.
    private static func matchesSavingsCategory(_ sub: Subscription, category: SubscriptionCategory) -> Bool {
        if sub.category == category.rawValue { return true }
        guard category == .streaming, (sub.category ?? "").isEmpty else { return false }
        return streamingServiceNames.contains(sub.name.lowercased())
    }

    private static func matchesSavingsCategoryName(_ sub: Subscription, name: String) -> Bool {
        if let category = SubscriptionCategory(rawValue: name) {
            return matchesSavingsCategory(sub, category: category)
        }
        return sub.category == name
    }

    /// Categories that currently have at least one subscription, in the app’s category order.
    private var ownedSavingsCategories: [String] {
        let subs = viewModel.subscriptions
        var names = SubscriptionCategory.allCases
            .filter { category in subs.contains { Self.matchesSavingsCategory($0, category: category) } }
            .map(\.rawValue)
        let known = Set(SubscriptionCategory.allNames)
        let extras = Set(subs.compactMap(\.category).filter { !$0.isEmpty && !known.contains($0) })
        names.append(contentsOf: extras.sorted())
        return names
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                    .padding(.top, 24)

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
                                    } else if goal == .categorySavings {
                                        categorySavingsPhase = .pickCategory
                                        savingsCategoryName = nil
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
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 16)
                                    .subHelpPanel(cornerRadius: 24)
                                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                }
                                .buttonStyle(.subHelpPressable)
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
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
            .background { SubHelpBackdrop() }
            .scrollContentBackground(.hidden)
            .animation(SubHelpTheme.smooth, value: selectedGoal)
            .animation(SubHelpTheme.smooth, value: isThinking)
            .animation(SubHelpTheme.smooth, value: save100Phase)
            .animation(SubHelpTheme.smooth, value: categorySavingsPhase)
            .navigationTitle("Help")
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
                categorySavingsPhase = .pickCategory
                savingsCategoryName = nil
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
            case .categorySavings:
                switch categorySavingsPhase {
                case .pickCategory:
                    categoryPickerContent
                case .thinking:
                    thinkingView
                        .padding(.vertical, 24)
                case .results:
                    categorySavingsContent
                }
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
                CurrencyAmountField(placeholder: "Amount", amount: $saveTargetInput, currencyCode: currencyCode)
                    .frame(width: 140)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .subHelpRow()
            .padding(.horizontal, 20)

            Button(action: runSave100Calculation) {
                Text("OK")
                    .font(.system(.body, design: .default, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.subHelp(fullWidth: true))
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
                CurrencyAmountField(placeholder: "Amount", amount: $saveTargetInput, currencyCode: currencyCode)
                    .frame(width: 140)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .subHelpRow()
            .padding(.horizontal, 20)

            Button(action: runSave100Calculation) {
                Text("OK")
                    .font(.system(.body, design: .default, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.subHelp(fullWidth: true))
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
            Text("Add subscriptions on the Subscriptions tab, then come back. I’ll show you combinations that add up to \(CurrencyOptions.formatPresentation(amount: targetYearly, currencyCode: currencyCode))/year or more.")
                .font(.system(.footnote, design: .default, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        } else {
            ForEach(Array(combinations.prefix(3).enumerated()), id: \.offset) { index, subs in
                let total = yearlyTotal(for: subs)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Option \(index + 1): Cancel these to save \(CurrencyOptions.formatPresentation(amount: total, currencyCode: currencyCode))/year")
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
        .subHelpRow()
    }

    // MARK: - Savings by category

    private func selectSavingsCategory(_ name: String) {
        savingsCategoryName = name
        categorySavingsPhase = .thinking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard selectedGoal == .categorySavings, savingsCategoryName == name else { return }
            categorySavingsPhase = .results
        }
    }

    private var categoryPickerContent: some View {
        let categories = ownedSavingsCategories

        return VStack(alignment: .leading, spacing: 16) {
            Text("Which category?")
                .font(.system(.title3, design: .default, weight: .bold))
                .padding(.horizontal, 20)

            if categories.isEmpty {
                Text("You don’t have any categorised subscriptions yet. Add them on the Subscriptions tab, then come back to see how much you’d save.")
                    .font(.system(.footnote, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(categories, id: \.self) { name in
                        Button {
                            selectSavingsCategory(name)
                        } label: {
                            HStack(spacing: 12) {
                                SubscriptionCategoryMark(category: name, size: 32, onColorCard: false)
                                Text(name)
                                    .font(.system(.subheadline, design: .default, weight: .medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .subHelpPanel(cornerRadius: 24)
                            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.subHelpPressable)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var categorySavingsContent: some View {
        let categoryName = savingsCategoryName ?? ""
        let matching = viewModel.subscriptions.filter { Self.matchesSavingsCategoryName($0, name: categoryName) }
        let yearlySavings = matching.reduce(Decimal.zero) { total, sub in
            total + yearlyAmount(for: sub)
        }

        return VStack(alignment: .leading, spacing: 16) {
            Text("See how much you’d save")
                .font(.system(.title3, design: .default, weight: .bold))
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                SubscriptionCategoryMark(category: categoryName, size: 32, onColorCard: false)
                Text(categoryName)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                Spacer()
                Button("Change") {
                    categorySavingsPhase = .pickCategory
                    savingsCategoryName = nil
                }
                .font(.system(.subheadline, design: .default, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .subHelpRow()
            .padding(.horizontal, 20)

            if matching.isEmpty {
                Text("You don’t have any \(categoryName) subscriptions listed yet. Add them on the Subscriptions tab to see how much you’d save by cancelling them.")
                    .font(.system(.footnote, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                (Text("If you remove your \(categoryName) subscriptions below, you’d save ")
                    + Text(CurrencyOptions.formatPresentation(amount: yearlySavings, currencyCode: currencyCode)).fontWeight(.semibold)
                    + Text(" per year."))
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(matching) { sub in
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
        let note = sub.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasStage = sub.stage != .keep
        let showLabels = hasStage || !note.isEmpty || sub.isTrial
        return HStack(alignment: .center, spacing: 12) {
            SubscriptionCategoryMark(category: sub.category)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(sub.name)
                        .font(.system(.headline, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(CurrencyOptions.formatPresentation(amount: sub.price, currencyCode: currencyCode))
                            .font(.system(.headline, design: .default, weight: .bold))
                            .foregroundStyle(.white)
                        Text(sub.frequency.shortLabel)
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                Text(sub.isTrial
                     ? "Trial ends: \(viewModel.nextPaymentString(for: sub.trialEndDate ?? sub.nextPaymentDate))"
                     : "Next payment: \(viewModel.nextPaymentString(for: sub.nextPaymentDate))")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if showLabels {
                    HStack(spacing: 6) {
                        if sub.isTrial {
                            SubscriptionLabelPill(text: "On free trial", kind: .trial)
                        }
                        if hasStage {
                            SubscriptionLabelPill(text: sub.stage.rawValue, kind: .stage(sub.stage))
                        }
                        if !note.isEmpty {
                            SubscriptionLabelPill(text: note, kind: .note)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .subHelpColorCard(sub.color)
    }

    // MARK: - Helpers

    private func yearlyAmount(for sub: Subscription) -> Decimal {
        sub.frequency.yearlyAmount(for: sub.price)
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
