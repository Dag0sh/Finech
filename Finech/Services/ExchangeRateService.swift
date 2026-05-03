import Foundation
import Combine

private struct CachedRates: Codable {
    let base: String
    let rates: [String: Double]
    let timestamp: Date
}

final class ExchangeRateService {
    static let shared = ExchangeRateService()

    private let cacheKey = "finech.exchange_rates_cache"
    private let cacheTTL: TimeInterval = 3600
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    // MARK: - Combine publisher (network layer)

    func ratesPublisher(base: String = "RUB") -> AnyPublisher<[String: Double], Error> {
        if let cached = loadCache(), cached.base == base,
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return Just(cached.rates)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        let url = URL(string: "https://api.exchangerate-api.com/v4/latest/\(base)")!
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: ExchangeRateResponse.self, decoder: decoder)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.saveCache(CachedRates(base: base, rates: response.rates, timestamp: Date()))
            })
            .map(\.rates)
            .eraseToAnyPublisher()
    }

    // MARK: - async/await (прямой, без Combine-моста)

    func fetchRates(base: String = "RUB") async throws -> [String: Double] {
        if let cached = loadCache(), cached.base == base,
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.rates
        }
        let url = URL(string: "https://api.exchangerate-api.com/v4/latest/\(base)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try decoder.decode(ExchangeRateResponse.self, from: data)
        saveCache(CachedRates(base: base, rates: response.rates, timestamp: Date()))
        return response.rates
    }

    // MARK: - Cache

    private func loadCache() -> CachedRates? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? decoder.decode(CachedRates.self, from: data)
    }

    private func saveCache(_ cached: CachedRates) {
        guard let data = try? encoder.encode(cached) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    func invalidateCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}
