import SwiftUI
import AVFoundation

struct SubscriptionDetailView: View {
    @Binding var subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    var onUnsubscribe: ((Subscription) -> Void)?

    @State private var showCelebration = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var audioPlayer: AVAudioPlayer?

    private let colorOptions: [(String, Color)] = [
        ("Red", Color(red: 0.89, green: 0.15, blue: 0.21)),
        ("Orange", Color(red: 0.24, green: 0.6, blue: 0.87)),
        ("Yellow", Color(red: 0.9, green: 0.5, blue: 0.13)),
        ("Green", Color(red: 0.11, green: 0.84, blue: 0.38)),
        ("Dark Green", Color(red: 0.07, green: 0.49, blue: 0.17)),
        ("Blue", Color(red: 0.0, green: 0.48, blue: 0.9)),
        ("Light Blue", Color(red: 0.35, green: 0.78, blue: 0.98)),
        ("Purple", Color(red: 0.6, green: 0.35, blue: 0.71)),
        ("Teal", Color(red: 0.29, green: 0.65, blue: 0.55)),
        ("Pink", Color(red: 0.9, green: 0.3, blue: 0.5))
    ]

    private let topCancelServices = [
        ("Netflix", "https://help.netflix.com/en/node/407"),
        ("Spotify", "https://support.spotify.com/us/article/how-to-cancel/"),
        ("Disney+", "https://help.disneyplus.com/article/disneyplus-cancel-subscription"),
        ("Amazon Prime", "https://www.amazon.co.uk/gp/help/customer/display.html?nodeId=G6LDPN7YJHYKH2J6"),
        ("YouTube Premium", "https://support.google.com/youtube/answer/6308278"),
        ("Apple One", "https://support.apple.com/en-gb/108043"),
        ("Xbox Game Pass", "https://support.xbox.com/en-GB/help/subscriptions-billing/manage-subscriptions/cancel-subscription"),
        ("PlayStation Plus", "https://www.playstation.com/en-gb/support/store/cancel-ps-store-subscription/"),
        ("Adobe CC", "https://helpx.adobe.com/uk/manage-account/using/cancel-subscription.html"),
        ("Microsoft 365", "https://support.microsoft.com/en-gb/office/cancel-a-microsoft-365-subscription-46e2634c-c64b-4c65-94b9-2cc9c960e91b")
    ]

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
        NavigationStack {
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
    }

    // MARK: - Sub Details

    private var subDetailsSection: some View {
        Section("Sub details") {
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
            NavigationLink {
                AppleSubscriptionView()
            } label: {
                Label("Auto cancel (Apple Subs)", systemImage: "apple.logo")
            }

            NavigationLink {
                topCancelGuideList
            } label: {
                Label("Cancel guide (top services)", systemImage: "list.number")
            }

            NavigationLink {
                GeneralCancelGuideView()
            } label: {
                Label("General cancel guide", systemImage: "questionmark.circle")
            }
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
                    Text("Mark as Unsubscribed")
                        .font(.system(.body, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 6)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private func triggerCelebration() {
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
                    onUnsubscribe?(subscription)
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
                if let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack {
                            Text(name)
                                .font(.system(.body, design: .default, weight: .regular))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

            Section("Via the App Store (Apple)") {
                Label("Settings → your name → Subscriptions", systemImage: "apple.logo")
            }

            Section("Via Google Play") {
                Label("Play Store → Menu → Subscriptions", systemImage: "play.fill")
            }

            Section("Via your bank") {
                Text("As a last resort, contact your bank to block future payments. Note: this may cause issues with the service provider.")
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Section("Tips") {
                Label("Screenshot confirmation emails", systemImage: "camera")
                Label("Check for a final billing date", systemImage: "calendar")
                Label("Look out for retention offers", systemImage: "tag")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("General Guide")
    }
}
