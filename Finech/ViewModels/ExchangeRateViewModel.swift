import Foundation
import Observation
import Combine

enum RateSort: String, CaseIterable {
    case popularity  = "Популярные"
    case code        = "A → Z"
    case rateHigh    = "Цена ↓"
    case rateLow     = "Цена ↑"
    case relevance   = "Рядом"

    var icon: String {
        switch self {
        case .popularity: "flame"
        case .code:       "textformat.abc"
        case .rateHigh:   "arrow.down"
        case .rateLow:    "arrow.up"
        case .relevance:  "location"
        }
    }
}

@Observable
final class ExchangeRateViewModel {
    var rates: [ExchangeRate] = []
    var base = "RUB"
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    // Упорядоченный массив избранных (max 4, FIFO)
    var favoriteCurrencies: [String] = []
    var showOnlyFavorites = false
    var currentSort: RateSort = .popularity
    var localCurrency: String = Locale.current.currency?.identifier ?? "USD"
    var rateSearchText = ""

    // ExchangeRate объекты для избранных (в порядке добавления)
    var favoriteRates: [ExchangeRate] {
        favoriteCurrencies.compactMap { code in rates.first { $0.currency == code } }
    }

    // Список с учётом поиска, фильтра избранного и сортировки
    var displayedRates: [ExchangeRate] {
        var source = showOnlyFavorites && !favoriteCurrencies.isEmpty
            ? rates.filter { favoriteCurrencies.contains($0.currency) }
            : rates

        if !rateSearchText.isEmpty {
            source = source.filter { rate in
                rate.currency.localizedCaseInsensitiveContains(rateSearchText) ||
                (Locale.current.localizedString(forCurrencyCode: rate.currency) ?? "")
                    .localizedCaseInsensitiveContains(rateSearchText)
            }
        }

        return applySorting(source)
    }

    private let favoritesKey = "finech.favorite_currencies"
    private let service = ExchangeRateService.shared
    private var cancellables = Set<AnyCancellable>()

    private let popularOrder = [
        "USD", "EUR", "GBP", "JPY", "CNY", "CHF", "CAD", "AUD",
        "HKD", "SGD", "KRW", "INR", "BRL", "MXN", "TRY", "RUB",
        "AED", "PLN", "SEK", "NOK", "DKK", "CZK", "HUF", "ZAR",
        "NZD", "THB", "MYR", "IDR", "PHP", "VND", "UAH", "KZT"
    ]

    init() {
        favoriteCurrencies = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
    }

    // MARK: - Network (Combine)

    func load() {
        isLoading = true
        errorMessage = nil

        service.ratesPublisher(base: base)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] dict in
                    guard let self else { return }
                    rates = dict
                        .map { ExchangeRate(currency: $0.key, rate: $0.value, flag: ExchangeRate.flag(for: $0.key)) }
                        .sorted { $0.currency < $1.currency }
                    lastUpdated = Date()
                }
            )
            .store(in: &cancellables)
    }

    func refresh() {
        service.invalidateCache()
        load()
    }

    // MARK: - Favourites (max 4, FIFO)

    func toggleFavorite(_ currency: String) {
        if let idx = favoriteCurrencies.firstIndex(of: currency) {
            favoriteCurrencies.remove(at: idx)
        } else {
            if favoriteCurrencies.count >= 4 { favoriteCurrencies.removeFirst() }
            favoriteCurrencies.append(currency)
        }
        UserDefaults.standard.set(favoriteCurrencies, forKey: favoritesKey)
    }

    func isFavorite(_ currency: String) -> Bool {
        favoriteCurrencies.contains(currency)
    }

    // MARK: - Sort

    private func applySorting(_ list: [ExchangeRate]) -> [ExchangeRate] {
        switch currentSort {
        case .code:        return list.sorted { $0.currency < $1.currency }
        case .rateHigh:    return list.sorted { $0.rate > $1.rate }
        case .rateLow:     return list.sorted { $0.rate < $1.rate }
        case .popularity:  return list.sorted { popularityRank($0.currency) < popularityRank($1.currency) }
        case .relevance:   return list.sorted { relevanceRank($0.currency) < relevanceRank($1.currency) }
        }
    }

    private func popularityRank(_ code: String) -> Int {
        popularOrder.firstIndex(of: code) ?? Int.max
    }

    private func relevanceRank(_ code: String) -> Int {
        code == localCurrency ? -1 : popularityRank(code)
    }

}
