import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (Subscription) -> Void

    @State private var name = ""
    @State private var price: Decimal?
    @State private var frequency: BillingFrequency = .monthly
    @State private var nextPaymentDate = Date()
    @State private var selectedColor = Color(red: 0.0, green: 0.48, blue: 0.9)

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

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (price ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("e.g. Netflix, Spotify", text: $name)
                        .font(.system(.body, design: .default, weight: .regular))
                }

                Section("Price") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("£0.00", value: $price, format: .currency(code: "GBP"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(BillingFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                }

                Section("Renewal date") {
                    DatePicker("Next payment", selection: $nextPaymentDate, displayedComponents: .date)
                }

                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(colorOptions, id: \.0) { name, color in
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .shadow(color: selectedColor == color ? color.opacity(0.5) : .clear, radius: 4)
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }

                // Preview card
                if !name.isEmpty {
                    Section("Preview") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.system(.headline, design: .default, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Next payment: \(nextPaymentDate.formatted(.dateTime.day().month(.wide)))")
                                    .font(.system(.subheadline, design: .default, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(price ?? 0, format: .currency(code: "GBP"))
                                    .font(.system(.headline, design: .default, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(frequency.shortLabel)
                                    .font(.system(.caption, design: .default, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(16)
                        .background(selectedColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let sub = Subscription(
                            name: name.trimmingCharacters(in: .whitespaces),
                            nextPaymentDate: nextPaymentDate,
                            price: price ?? 0,
                            color: selectedColor,
                            frequency: frequency
                        )
                        onAdd(sub)
                        dismiss()
                    }
                    .font(.system(.body, design: .default, weight: .bold))
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    AddSubscriptionView { _ in }
}
