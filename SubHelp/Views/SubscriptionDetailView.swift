import SwiftUI
import AVFoundation
import UIKit

struct SubscriptionDetailView: View {
    @Binding var subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    var onUnsubscribe: ((Subscription) -> Void)?

    @State private var showCelebration = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var audioPlayer: AVAudioPlayer?

    // 3 rows of colours (5 per row)
    private let colorOptions: [(String, Color)] = [
        ("Red", Color(red: 0.89, green: 0.15, blue: 0.21)),
        ("Coral", Color(red: 0.94, green: 0.33, blue: 0.31)),
        ("Orange", Color(red: 0.95, green: 0.55, blue: 0.15)),
        ("Amber", Color(red: 0.9, green: 0.7, blue: 0.1)),
        ("Yellow", Color(red: 0.95, green: 0.85, blue: 0.15)),

        ("Lime", Color(red: 0.55, green: 0.82, blue: 0.15)),
        ("Green", Color(red: 0.11, green: 0.84, blue: 0.38)),
        ("Dark Green", Color(red: 0.07, green: 0.49, blue: 0.17)),
        ("Teal", Color(red: 0.15, green: 0.68, blue: 0.62)),
        ("Cyan", Color(red: 0.2, green: 0.75, blue: 0.85)),

        ("Light Blue", Color(red: 0.35, green: 0.78, blue: 0.98)),
        ("Blue", Color(red: 0.0, green: 0.48, blue: 0.9)),
        ("Indigo", Color(red: 0.24, green: 0.31, blue: 0.71)),
        ("Purple", Color(red: 0.6, green: 0.35, blue: 0.71)),
        ("Pink", Color(red: 0.9, green: 0.3, blue: 0.5)),
    ]

    private let topCancelServices: [(String, String)] = {
        let services: [(String, String)] = [
            ("Adobe Creative Cloud", "https://helpx.adobe.com/uk/manage-account/using/cancel-subscription.html"),
            ("Amazon Prime", "https://www.amazon.co.uk/gp/help/customer/display.html?nodeId=G6LDPN7YJHYKH2J6"),
            ("Apple One", "https://support.apple.com/en-gb/108043"),
            ("Audible", "https://help.audible.co.uk/s/article/cancel-membership"),
            ("Calm (Premium)", "https://www.calm.com/account/cancel"),
            ("Canva Pro", "https://www.canva.com/help/article/cancel-subscription"),
            ("ChatGPT Plus", "https://help.openai.com/en/articles/8553578-how-do-i-cancel-my-subscription"),
            ("Claude Pro", "https://support.anthropic.com/en/articles/9154643-how-do-i-cancel-my-claude-pro-subscription"),
            ("Copilot Pro", "https://support.microsoft.com/en-gb/topic/how-to-cancel-your-microsoft-copilot-pro-subscription-ae14e0ac-e8b5-4bdc-9a47-81ff4fc97adc"),
            ("Coursera", "https://support.coursera.org/hc/en-us/articles/208280056-How-do-I-cancel-my-subscription-"),
            ("Crunchyroll", "https://help.crunchyroll.com/hc/en-us/articles/360048429352-How-do-I-cancel-my-subscription-"),
            ("DAZN", "https://www.dazn.com/help/articles/how-do-i-cancel-my-subscription"),
            ("Discord Nitro", "https://discord.com/support/article/how-do-i-cancel-my-subscription"),
            ("Disney+", "https://help.disneyplus.com/article/disneyplus-manage-subscription"),
            ("Dropbox", "https://help.dropbox.com/accounts-billing/cancel-subscription"),
            ("Duolingo Plus", "https://support.duolingo.com/hc/en-us/articles/115002331208-How-do-I-cancel-my-subscription-"),
            ("EA Play", "https://www.ea.com/help/ea-play/cancel-membership"),
            ("Evernote", "https://help.evernote.com/hc/en-us/articles/209005257-How-to-cancel-your-Evernote-subscription"),
            ("Gemini Advanced", "https://support.google.com/gemini/answer/13257891"),
            ("Google One", "https://support.google.com/one/answer/6304836"),
            ("Grammarly Premium", "https://support.grammarly.com/hc/en-us/articles/115000090792-How-do-I-cancel-my-Grammarly-subscription-"),
            ("Headspace", "https://help.headspace.com/hc/en-us/articles/360018462231-How-do-I-cancel-my-subscription-"),
            ("Kindle Unlimited", "https://www.amazon.co.uk/gp/help/customer/display.html?nodeId=201555520"),
            ("LinkedIn Premium", "https://www.linkedin.com/help/linkedin/answer/133"),
            ("Max (HBO)", "https://help.max.com/questions/cancel-subscription"),
            ("Microsoft 365", "https://support.microsoft.com/en-gb/office/cancel-a-microsoft-365-subscription-46e2634c-c64b-4c65-94b9-2cc9c960e91b"),
            ("MyFitnessPal Premium", "https://www.myfitnesspal.com/account/cancel_subscription"),
            ("Nest Aware", "https://support.google.com/googlenest/answer/7073613"),
            ("Netflix", "https://help.netflix.com/en/node/407"),
            ("Nintendo Switch Online", "https://en-americas-support.nintendo.com/app/answers/detail/a_id/52090"),
            ("Notion", "https://www.notion.so/help/cancel-your-subscription"),
            ("Perplexity Pro", "https://www.perplexity.ai/settings"),
            ("PlayStation Plus", "https://www.playstation.com/en-gb/support/store/cancel-ps-store-subscription/"),
            ("Ring Protect", "https://support.ring.com/hc/en-us/articles/360060445191-How-to-cancel-your-Ring-Protect-subscription"),
            ("Spotify", "https://support.spotify.com/article/cancel-premium/"),
            ("Strava", "https://support.strava.com/hc/en-us/articles/216918437-How-do-I-cancel-my-Strava-Subscription-"),
            ("Uber One", "https://www.uber.com/help/article/cancel-uber-one"),
            ("Xbox Game Pass", "https://support.xbox.com/en-GB/help/subscriptions-billing/manage-subscriptions/cancel-subscription"),
            ("YouTube Premium", "https://support.google.com/youtube/answer/6308278"),
            ("Zoom", "https://support.zoom.us/hc/en-us/articles/201363083-How-do-I-cancel-my-subscription-"),
        ]
        return services.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }()

    private var savingsText: String {
        let amount = subscription.price
        let formatted = amount.formatted(.currency(code: currencyCode))
        switch subscription.frequency {
        case .weekly: return "\(formatted) per week"
        case .monthly: return "\(formatted) per month"
        case .yearly: return "\(formatted) per year"
        }
    }

    var body: some View {
        ZStack {
            List {
                subDetailsSection
                cancellationHelpSection
                unsubscribeSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(subscription.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .default, weight: .semibold))
                }
            }

            if showCelebration {
                celebrationOverlay
            }
        }
    }

    // MARK: - Sub Details

    private var subDetailsSection: some View {
        Section("Sub details") {
            Picker("Category", selection: Binding(
                get: { subscription.category ?? "" },
                set: { newVal in
                    var s = subscription
                    s.category = newVal.isEmpty ? nil : newVal
                    subscription = s
                }
            )) {
                Text("None").tag("")
                ForEach(SubscriptionCategory.allNames, id: \.self) { cat in
                    Text(cat).tag(cat)
                }
            }

            Picker("Frequency", selection: $subscription.frequency) {
                ForEach(BillingFrequency.allCases, id: \.self) { freq in
                    Text(freq.rawValue).tag(freq)
                }
            }

            HStack {
                Text("Amount")
                Spacer()
                TextField("Price", value: $subscription.price, format: .currency(code: currencyCode))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }

            DatePicker("When it renews", selection: $subscription.nextPaymentDate, displayedComponents: .date)

            VStack(alignment: .leading, spacing: 10) {
                Text("Background colour")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(colorOptions, id: \.0) { name, color in
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: subscription.color == color ? 3 : 0)
                            )
                            .shadow(color: subscription.color == color ? color.opacity(0.5) : .clear, radius: 4)
                            .onTapGesture {
                                subscription.color = color
                            }
                    }
                }
            }
        }
    }

    // MARK: - Cancellation Help

    private var cancellationHelpSection: some View {
        Section("Cancellation help") {
            // Intro
            VStack(alignment: .leading, spacing: 6) {
                Text("Here you’ll find different ways to cancel this subscription.")
                    .font(.system(.footnote, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            // Step 1: Apple subscriptions
            VStack(alignment: .leading, spacing: 10) {
                Text("1. Apple subscriptions")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                Text("Click below to see if this subscription is being paid for with your Apple account. You can cancel there.")
                    .font(.system(.footnote, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                Button {
                    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Check Apple subscriptions", systemImage: "arrow.up.right.square")
                        .font(.system(.subheadline, design: .default, weight: .medium))
                }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // Step 2: Popular services guides
            VStack(alignment: .leading, spacing: 8) {
                Text("2. Popular services guide")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                Text("Step-by-step how to unsubscribe or cancel for common services.")
                    .font(.system(.footnote, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            NavigationLink {
                topCancelGuideList
            } label: {
                Label("Cancel guide (popular services)", systemImage: "list.number")
            }
            .buttonStyle(.borderless)

            // Step 3: General advice
            VStack(alignment: .leading, spacing: 8) {
                Text("3. General guide")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                Text("General steps for cancelling via the service's website or Apple.")
                    .font(.system(.footnote, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            NavigationLink {
                GeneralCancelGuideView()
            } label: {
                Label("General cancel guide", systemImage: "questionmark.circle")
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Unsubscribe

    private var unsubscribeSection: some View {
        Section {
            Button {
                triggerCelebration()
            } label: {
                HStack {
                    Spacer()
                    Label("Mark as Unsubscribed", systemImage: "checkmark.circle.fill")
                        .font(.system(.body, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(.green)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private func triggerCelebration() {
        // Fire the callback immediately so the subscription moves to History
        // before the sheet is dismissed or the binding is invalidated.
        onUnsubscribe?(subscription)

        playSuccessSound()
        spawnConfetti()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showCelebration = true
        }
        let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
        impactHeavy.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
        }
    }

    private func playSuccessSound() {
        AudioServicesPlaySystemSound(1025)
    }

    private func spawnConfetti() {
        confettiParticles = (0..<60).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: -100...(-20)),
                color: [Color.red, .blue, .green, .yellow, .orange, .purple, .pink, .mint].randomElement()!,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                delay: Double.random(in: 0...0.4)
            )
        }
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showCelebration = false
                    }
                    dismiss()
                }

            // Confetti
            ForEach(confettiParticles) { particle in
                ConfettiView(particle: particle)
            }

            // Celebration card
            VStack(spacing: 16) {
                Image("ShibaMascot")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())

                Text("Yay!")
                    .font(.system(size: 36, weight: .black, design: .default))

                Text("You save \(savingsText) now!")
                    .font(.system(.title3, design: .default, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("Tap anywhere to close")
                    .font(.system(.caption, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var topCancelGuideList: some View {
        List {
            ForEach(topCancelServices, id: \.0) { name, urlString in
                Button {
                    if let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text(name)
                            .font(.system(.body, design: .default, weight: .regular))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cancel Guides")
    }
}

// MARK: - Confetti

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let delay: Double
}

struct ConfettiView: View {
    let particle: ConfettiParticle
    @State private var fallen = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 0.6)
            .rotationEffect(.degrees(fallen ? particle.rotation + 360 : particle.rotation))
            .position(
                x: particle.x + (fallen ? CGFloat.random(in: -30...30) : 0),
                y: fallen ? UIScreen.main.bounds.height + 50 : particle.y
            )
            .onAppear {
                withAnimation(.easeIn(duration: Double.random(in: 1.5...2.5)).delay(particle.delay)) {
                    fallen = true
                }
            }
    }
}

// MARK: - Apple Subscription View

struct AppleSubscriptionView: View {
    var body: some View {
        List {
            Section {
                Text("If you subscribed through the App Store, you can manage and cancel directly from your Apple ID settings.")
                    .font(.system(.body, design: .default, weight: .regular))
            }

            Section("Steps") {
                Label("Open the Settings app", systemImage: "1.circle.fill")
                Label("Tap your name at the top", systemImage: "2.circle.fill")
                Label("Tap Subscriptions", systemImage: "3.circle.fill")
                Label("Tap the subscription to cancel", systemImage: "4.circle.fill")
                Label("Tap Cancel Subscription", systemImage: "5.circle.fill")
            }

            Section {
                Button("Open Subscription Settings") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(.body, design: .default, weight: .semibold))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Apple Subscriptions")
    }
}

// MARK: - General Cancel Guide

struct GeneralCancelGuideView: View {
    var body: some View {
        List {
            Section("Via the service's website") {
                Label("Log in to the service's website", systemImage: "1.circle.fill")
                Label("Go to Account or Settings", systemImage: "2.circle.fill")
                Label("Look for Subscription or Billing", systemImage: "3.circle.fill")
                Label("Click Cancel / End subscription", systemImage: "4.circle.fill")
                Label("Confirm the cancellation", systemImage: "5.circle.fill")
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("General Guide")
    }
}
