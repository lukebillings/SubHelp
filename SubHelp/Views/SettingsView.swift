import SwiftUI
import StoreKit
import UserNotifications

struct SettingsView: View {
    @AppStorage("notificationDaysBefore") private var notificationDaysBefore: Int = 1
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Currency") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(CurrencyOptions.topCurrencies, id: \.code) { currency in
                            Text(currency.label).tag(currency.code)
                        }
                        Divider()
                        ForEach(CurrencyOptions.otherCurrencies, id: \.code) { currency in
                            Text(currency.label).tag(currency.code)
                        }
                    }
                    .font(.system(.body, design: .default, weight: .regular))
                    .onChange(of: currencyCode) { _, _ in
                        RenewalNotificationScheduler.scheduleRenewalReminders()
                    }
                }

                Section("Notifications") {
                    Picker("Days before renewal", selection: $notificationDaysBefore) {
                        Text("Never").tag(-1)
                        Text("Same day").tag(0)
                        Text("1 day before").tag(1)
                        Text("2 days before").tag(2)
                        Text("3 days before").tag(3)
                        Text("1 week before").tag(7)
                    }
                    .font(.system(.body, design: .default, weight: .regular))
                    .onChange(of: notificationDaysBefore) { _, newVal in
                        UserDefaults.standard.set(true, forKey: "subhelp.didCompleteNotificationSetup")
                        if newVal >= 0 {
                            Task {
                                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                                await MainActor.run {
                                    RenewalNotificationScheduler.scheduleRenewalReminders()
                                }
                            }
                        } else {
                            RenewalNotificationScheduler.scheduleRenewalReminders()
                        }
                    }
                }

                Section("Other") {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptics", systemImage: "hand.tap")
                    }

                    Button {
                        requestAppStoreRating()
                    } label: {
                        Label("Rate", systemImage: "star.fill")
                    }

                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset all data", systemImage: "trash")
                    }
                }
                .font(.system(.body, design: .default, weight: .regular))

                Section("Legal") {
                    Link(destination: URL(string: "https://lukebillings.github.io/SubHelp/termsandconditions/index.html")!) {
                        Label("Terms and Conditions", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://lukebillings.github.io/SubHelp/privacypolicy/index.html")!) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                }
                .font(.system(.body, design: .default, weight: .regular))
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .alert("Reset all data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    NotificationCenter.default.post(name: .subhelpResetAllData, object: nil)
                }
            } message: {
                Text("This removes all subscriptions, history, and settings. The app will start as if you just downloaded it.")
            }
        }
    }

    private func requestAppStoreRating() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }
}

#Preview {
    SettingsView()
}
