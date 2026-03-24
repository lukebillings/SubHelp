import SwiftUI

struct CurrencyOnboardingView: View {
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"
    @AppStorage("hasCompletedCurrencyOnboarding") private var hasCompletedCurrencyOnboarding = false
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Select currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        RenewalNotificationScheduler.scheduleRenewalReminders()
                        hasCompletedCurrencyOnboarding = true
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    CurrencyOnboardingView(isPresented: .constant(true))
}
