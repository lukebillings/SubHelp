import SwiftUI
import StoreKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var premiumProducts: PremiumSubscriptionProducts
    @AppStorage("notificationDaysBefore") private var notificationDaysBefore: Int = 1
    @AppStorage(RenewalNotificationScheduler.notificationsEnabledKey) private var notificationsEnabled = true
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @AppStorage("subscriptionTier") private var subscriptionTierRaw: String = SubscriptionTier.free.rawValue
    @AppStorage(SubHelpHaptics.userDefaultsKey) private var hapticsEnabled = true

    /// Opens the correct regional App Store when opened (no `/us/` in path).
    private static let appStoreShareURL = URL(string: "https://apps.apple.com/app/id6761027229")!

    @State private var showResetConfirmation = false
    @State private var isRestoringPurchases = false
    @State private var restoreAlertMessage: String?

    private var subscriptionTier: SubscriptionTier {
        SubscriptionTier(rawValue: subscriptionTierRaw) ?? .free
    }

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

                Section {
                    Toggle("App notifications", isOn: $notificationsEnabled)
                        .font(.system(.body, design: .default, weight: .regular))
                        .onChange(of: notificationsEnabled) { _, isOn in
                            UserDefaults.standard.set(true, forKey: "subhelp.didCompleteNotificationSetup")
                            SubHelpHaptics.impact(.light)
                            if isOn {
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

                    Picker("Reminder timing", selection: $notificationDaysBefore) {
                        Text("Same day").tag(0)
                        Text("1 day before").tag(1)
                        Text("2 days before").tag(2)
                        Text("3 days before").tag(3)
                        Text("1 week before").tag(7)
                        Text("Never").tag(-1)
                    }
                    .font(.system(.body, design: .default, weight: .regular))
                    .disabled(!notificationsEnabled)
                    .onChange(of: notificationDaysBefore) { _, _ in
                        UserDefaults.standard.set(true, forKey: "subhelp.didCompleteNotificationSetup")
                        RenewalNotificationScheduler.scheduleRenewalReminders()
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Turn off App notifications to stop all SubHelp alerts. Reminder timing controls how early you get subscription renewal reminders; choose Never to keep notifications on without renewal alerts.")
                        .font(.system(.caption, design: .default, weight: .regular))
                }

                Section("Haptics") {
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                        .font(.system(.body, design: .default, weight: .regular))
                        .onChange(of: hapticsEnabled) { _, isOn in
                            if isOn {
                                SubHelpHaptics.impact(.light)
                            }
                        }
                }

                Section("Other") {
                    Button {
                        SubHelpHaptics.impact(.light)
                        requestAppStoreRating()
                    } label: {
                        Label("Rate SubHelp", systemImage: "star.fill")
                    }

                    ShareLink(item: Self.appStoreShareURL) {
                        Label("Share SubHelp", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        SubHelpHaptics.impact(.light)
                        showResetConfirmation = true
                    } label: {
                        Label("Reset all data", systemImage: "trash")
                    }
                }
                .font(.system(.body, design: .default, weight: .regular))

                Section("Purchases") {
                    Button {
                        SubHelpHaptics.impact(.light)
                        Task { await restorePurchases() }
                    } label: {
                        HStack {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                            Spacer()
                            if isRestoringPurchases {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoringPurchases)

                    Text("If you subscribed before—on this iPhone or another—you can restore access here.")
                        .font(.system(.caption, design: .default, weight: .regular))
                        .foregroundStyle(.secondary)
                }

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
            .onAppear {
                migrateLegacyNotificationNeverIfNeeded()
            }
            .navigationTitle("Settings")
            .alert("Reset all data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    NotificationCenter.default.post(name: .subhelpResetAllData, object: nil)
                }
            } message: {
                Text("This removes all subscriptions, history, and settings. The app will start as if you just downloaded it.")
            }
            .alert("Restore Purchases", isPresented: Binding(
                get: { restoreAlertMessage != nil },
                set: { if !$0 { restoreAlertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreAlertMessage ?? "")
            }
        }
    }

    /// Legacy installs stored “no renewal reminders” as `notificationDaysBefore == -1` without the master toggle key; sync that implied state without clearing Never.
    private func migrateLegacyNotificationNeverIfNeeded() {
        guard UserDefaults.standard.object(forKey: RenewalNotificationScheduler.notificationsEnabledKey) == nil else { return }
        guard (UserDefaults.standard.object(forKey: "notificationDaysBefore") as? Int) == -1 else { return }
        UserDefaults.standard.set(false, forKey: RenewalNotificationScheduler.notificationsEnabledKey)
        notificationsEnabled = false
    }

    private func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }
        if let error = await premiumProducts.restorePurchases() {
            restoreAlertMessage = error
        } else {
            restoreAlertMessage = String(localized: "Your purchases were synced with the App Store.")
        }
    }

    private func requestAppStoreRating() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }
}

#Preview {
    SettingsView()
        .environmentObject(PremiumSubscriptionProducts())
}
