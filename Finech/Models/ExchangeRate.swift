import Foundation

struct ExchangeRateResponse: Codable {
    let base: String
    let rates: [String: Double]
}

struct ExchangeRate: Identifiable, Equatable {
    var id: String { currency }
    let currency: String
    let rate: Double
    let flag: String

    // Генерирует флаг через Unicode regional indicator letters
    // "US" → 🇺🇸, "EU" → 🇪🇺, "RU" → 🇷🇺 и т.д. для ~150 валют
    static func flag(for code: String) -> String {
        guard !code.hasPrefix("X") else { return "🌐" }
        let base: UInt32 = 127397 // смещение: 'A'.unicodeScalar + 127397 = 🇦
        return String(code.prefix(2)).uppercased().unicodeScalars
            .compactMap { UnicodeScalar($0.value + base) }
            .map { String($0) }
            .joined()
    }
}
