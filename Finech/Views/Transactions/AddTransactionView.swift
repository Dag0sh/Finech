import SwiftUI
import CoreLocation

struct AddTransactionView: View {
    @Environment(TransactionViewModel.self) var vm
    @Environment(\.dismiss) var dismiss

    var editingTransaction: Transaction?

    @State private var amountText = ""
    @State private var selectedCurrency = "RUB"
    @State private var selectedType = TransactionType.expense
    @State private var selectedCategory = TransactionCategory.food
    @State private var note = ""
    @State private var attachLocation = false
    @State private var locationManager = LocationManager()

    private var isEditMode: Bool { editingTransaction != nil }
    private var amount: Double { Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var isValid: Bool { amount > 0 }

    private let currencies = ["RUB", "USD", "EUR", "GBP", "CNY", "JPY", "TRY", "AED", "CHF", "KZT"]

    private var rubEquivalent: Double? {
        guard selectedCurrency != "RUB", amount > 0,
              let rate = vm.exchangeRates[selectedCurrency], rate > 0
        else { return nil }
        return amount / rate
    }

    private var filteredCategories: [TransactionCategory] {
        TransactionCategory.allCases.filter { $0.defaultType == selectedType || $0 == .other }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    amountHero
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    VStack(spacing: 16) {
                        categoryGrid
                        noteCard
                        locationCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditMode ? "Изменить" : "Новая транзакция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "Сохранить" : "Добавить") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    // MARK: - Hero amount block

    private var amountHero: some View {
        VStack(spacing: 16) {
            // Type picker
            Picker("", selection: $selectedType) {
                Text("Расход").tag(TransactionType.expense)
                Text("Доход").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedType) { _, newType in
                if selectedCategory.defaultType != newType {
                    selectedCategory = newType == .income ? .salary : .food
                }
            }

            // Amount + currency
            VStack(spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)

                    Picker("", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { code in
                            Text("\(ExchangeRate.flag(for: code)) \(code)").tag(code)
                        }
                    }
                    .labelsHidden()
                    .tint(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

                if let rub = rubEquivalent {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.caption2)
                        Text("≈ " + rub.formatted(.currency(code: "RUB")))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: rubEquivalent != nil)
        }
    }

    // MARK: - Category grid

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Категория")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                ForEach(filteredCategories, id: \.self) { cat in
                    VStack(spacing: 5) {
                        CategoryIconView(category: cat, size: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 46 * 0.28)
                                    .stroke(selectedCategory == cat ? cat.color.swiftUIColor : .clear, lineWidth: 2.5)
                                    .padding(-3)
                            )
                        Text(cat.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(selectedCategory == cat ? cat.color.swiftUIColor : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .onTapGesture { selectedCategory = cat }
                    .animation(.easeInOut(duration: 0.15), value: selectedCategory)
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: - Note

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Заметка")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.secondary)
                TextField("Описание (необязательно)", text: $note)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: - Location

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Геолокация")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                    Toggle("Прикрепить местоположение", isOn: $attachLocation)
                        .onChange(of: attachLocation) { _, enabled in
                            if enabled { locationManager.requestLocation() }
                            else { locationManager.reset() }
                        }
                }
                .padding(14)

                if attachLocation {
                    Divider().padding(.leading, 42)

                    Group {
                        if locationManager.isLocating {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Определяем координаты…")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let coord = locationManager.coordinate {
                            Label(
                                String(format: "%.4f, %.4f", coord.latitude, coord.longitude),
                                systemImage: "location.fill"
                            )
                            .foregroundStyle(.green)
                        } else if locationManager.authorizationStatus == .denied {
                            Label("Доступ к геолокации запрещён", systemImage: "location.slash")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: - Logic

    private func prefill() {
        guard let t = editingTransaction else { return }
        amountText = String(t.amount)
        selectedCurrency = t.currency
        selectedType = t.type
        selectedCategory = t.category
        note = t.note
        if let coord = t.coordinate {
            attachLocation = true
            locationManager.coordinate = coord
        }
    }

    private func save() {
        let coordinate: CLLocationCoordinate2D? = attachLocation ? locationManager.coordinate : nil

        if isEditMode, var updated = editingTransaction {
            updated.amount = amount
            updated.currency = selectedCurrency
            updated.type = selectedType
            updated.category = selectedCategory
            updated.note = note
            updated.coordinate = coordinate
            vm.update(updated)
        } else {
            vm.add(
                amount: amount,
                currency: selectedCurrency,
                type: selectedType,
                category: selectedCategory,
                note: note,
                coordinate: coordinate
            )
        }
        dismiss()
    }
}
