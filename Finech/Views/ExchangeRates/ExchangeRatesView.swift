import SwiftUI

struct ExchangeRatesView: View {
    @Environment(ExchangeRateViewModel.self) var vm

    private let baseCurrencies = ["RUB", "USD", "EUR", "CNY"]

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.rates.isEmpty {
                    ProgressView("Загружаем курсы...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.rates.isEmpty {
                    errorView(message: error)
                } else {
                    ratesList
                }
            }
            .navigationTitle("Курсы валют")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Обновить", systemImage: "arrow.clockwise") {
                        Task { await vm.refresh() }
                    }
                    .disabled(vm.isLoading)
                }
                ToolbarItem(placement: .secondaryAction) {
                    // Переключатель "только избранные"
                    Button(
                        vm.showOnlyFavorites ? "Все" : "Избранные",
                        systemImage: vm.showOnlyFavorites ? "star.slash" : "star"
                    ) {
                        vm.showOnlyFavorites.toggle()
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    // Меню сортировки
                    Menu {
                        ForEach(RateSort.allCases, id: \.self) { sort in
                            Button {
                                vm.currentSort = sort
                            } label: {
                                Label(sort.rawValue, systemImage: sort.icon)
                            }
                            .buttonStyle(.plain)
                        }
                    } label: {
                        Label(vm.currentSort.rawValue, systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.refresh() }
            .searchable(
                text: Bindable(vm).rateSearchText,
                prompt: "Код или название (USD, Dollar...)"
            )
        }
    }

    // MARK: - Subviews

    private var ratesList: some View {
        List {
            Section {
                Picker("База", selection: Bindable(vm).base) {
                    ForEach(baseCurrencies, id: \.self) { currency in
                        Text("\(ExchangeRate.flag(for: currency)) \(currency)").tag(currency)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.base) { _, _ in
                    Task { await vm.load() }
                }
            } header: {
                Text("Базовая валюта")
            }

            Section {
                if vm.showOnlyFavorites && vm.favoriteCurrencies.isEmpty {
                    Text("Нажмите ★ чтобы добавить валюту в избранное")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if vm.displayedRates.isEmpty && !vm.rateSearchText.isEmpty {
                    Text("Ничего не найдено по запросу «\(vm.rateSearchText)»")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.displayedRates) { rate in
                        RateRow(rate: rate, isFavorite: vm.isFavorite(rate.currency)) {
                            vm.toggleFavorite(rate.currency)
                        }
                    }
                }
            } header: {
                HStack {
                    if let updated = vm.lastUpdated {
                        Text("Обновлено: \(updated.formatted(date: .omitted, time: .shortened))")
                    }
                    Spacer()
                    Text("Сортировка: \(vm.currentSort.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(alignment: .top) {
            if vm.isLoading { ProgressView().padding(.top, 8) }
        }
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Ошибка загрузки", systemImage: "wifi.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Повторить") { Task { await vm.load() } }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - RateRow

private struct RateRow: View {
    let rate: ExchangeRate
    let isFavorite: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(rate.flag)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(rate.currency)
                    .font(.headline)
                Text(currencyName(rate.currency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(rate.rate, format: .number.precision(.fractionLength(4)))
                .font(.headline)
                .fontDesign(.monospaced)
            Button(action: onToggle) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
    }

    private func currencyName(_ code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }
}
