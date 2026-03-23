import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode: String = "GBP"

    var onAdd: (Subscription) -> Void

    @State private var name: String = ""
    @State private var category: String? = nil
    @State private var price: Decimal? = nil
    @State private var frequency: BillingFrequency = .monthly
    @State private var nextPaymentDate = Date()
    @State private var selectedColor = Color(red: 0.0, green: 0.48, blue: 0.9)

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

                Section("Category") {
                    Picker("Category", selection: Binding(
                        get: { category ?? "" },
                        set: { category = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("None").tag("")
                        ForEach(SubscriptionCategory.allNames, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }

                Section("Price") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", value: $price, format: .currency(code: currencyCode))
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
                        ForEach(colorOptions, id: \.0) { _, color in
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
                                Text(price ?? 0, format: .currency(code: currencyCode))
                                    .font(.system(.headline, design: .default, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(frequency.shortLabel)
                                    .font(.system(.caption, design: .default, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(16)
                        .background(selectedColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    Button("Save") {
                        guard let price = price else { return }
                        let sub = Subscription(
                            name: name,
                            nextPaymentDate: nextPaymentDate,
                            price: price,
                            color: selectedColor,
                            frequency: frequency,
                            category: category
                        )
                        onAdd(sub)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

