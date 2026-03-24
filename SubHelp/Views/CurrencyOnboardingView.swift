import SwiftUI
import UserNotifications

struct CurrencyOnboardingView: View {
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @AppStorage("hasCompletedCurrencyOnboarding") private var hasCompletedCurrencyOnboarding = false
    @Binding var isPresented: Bool
    /// Called after the user finishes the walkthrough (reminders on or not now).
    var onComplete: () -> Void = {}

    @State private var step = 0

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 {
                    currencyStep
                } else {
                    notificationStep
                }
            }
            .navigationTitle(step == 0 ? "Select currency" : "Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if step == 0 {
                        Button("Continue") {
                            step = 1
                        }
                        .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if step == 1 {
                        Button("Back") {
                            step = 0
                        }
                    }
                }
            }
        }
    }

    private var currencyStep: some View {
        List {
            Section {
                Text("Choose the currency SubHelp uses for subscription prices and totals. You can change this anytime in Settings.")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

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
            }
        }
    }

    private var notificationStep: some View {
        List {
            Section {
                Text("We can remind you before each subscription renews. You can change this anytime in Settings.")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    Task {
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        if (UserDefaults.standard.object(forKey: "notificationDaysBefore") as? Int) == -1 {
                            UserDefaults.standard.set(1, forKey: "notificationDaysBefore")
                        }
                        await MainActor.run {
                            completeOnboarding()
                        }
                    }
                } label: {
                    Label("Turn on reminders", systemImage: "bell.badge")
                }

                Button(role: .none) {
                    UserDefaults.standard.set(-1, forKey: "notificationDaysBefore")
                    completeOnboarding()
                } label: {
                    Label("Not now", systemImage: "bell.slash")
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "subhelp.didCompleteNotificationSetup")
        RenewalNotificationScheduler.scheduleRenewalReminders()
        hasCompletedCurrencyOnboarding = true
        isPresented = false
        onComplete()
    }
}

#Preview {
    CurrencyOnboardingView(isPresented: .constant(true))
}
