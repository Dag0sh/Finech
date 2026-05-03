import Foundation
import CoreLocation
import SwiftUI

enum TransactionType: String, CaseIterable, Codable {
    case income = "income"
    case expense = "expense"
}

enum TransactionCategory: String, CaseIterable, Codable {
    case food = "Еда"
    case transport = "Транспорт"
    case entertainment = "Развлечения"
    case health = "Здоровье"
    case shopping = "Покупки"
    case utilities = "Коммуналка"
    case salary = "Зарплата"
    case investment = "Инвестиции"
    case other = "Прочее"

    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .entertainment: "gamecontroller.fill"
        case .health: "heart.fill"
        case .shopping: "bag.fill"
        case .utilities: "bolt.fill"
        case .salary: "banknote.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: TransactionColor {
        switch self {
        case .food: .orange
        case .transport: .blue
        case .entertainment: .purple
        case .health: .red
        case .shopping: .pink
        case .utilities: .yellow
        case .salary: .green
        case .investment: .teal
        case .other: .gray
        }
    }

    var defaultType: TransactionType {
        switch self {
        case .salary, .investment: .income
        default: .expense
        }
    }
}

enum TransactionColor: String {
    case orange, blue, purple, red, pink, yellow, green, teal, gray

    var swiftUIColor: Color {
        switch self {
        case .orange: .orange
        case .blue:   .blue
        case .purple: .purple
        case .red:    .red
        case .pink:   .pink
        case .yellow: .yellow
        case .green:  .green
        case .teal:   .teal
        case .gray:   .gray
        }
    }
}

struct Transaction: Identifiable, Hashable {
    let id: UUID
    var amount: Double
    var currency: String
    var type: TransactionType
    var category: TransactionCategory
    var note: String
    var date: Date
    var coordinate: CLLocationCoordinate2D?

    var isIncome: Bool { type == .income }

    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id &&
        lhs.amount == rhs.amount &&
        lhs.currency == rhs.currency &&
        lhs.type == rhs.type &&
        lhs.category == rhs.category &&
        lhs.note == rhs.note &&
        lhs.date == rhs.date &&
        lhs.coordinate?.latitude == rhs.coordinate?.latitude &&
        lhs.coordinate?.longitude == rhs.coordinate?.longitude
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Transaction {
    init(from entity: TransactionEntity) {
        id = entity.id ?? UUID()
        amount = entity.amount
        currency = entity.currency ?? "RUB"
        type = TransactionType(rawValue: entity.type ?? "") ?? .expense
        category = TransactionCategory(rawValue: entity.category ?? "") ?? .other
        note = entity.note ?? ""
        date = entity.date ?? Date()
        coordinate = entity.hasLocation
            ? CLLocationCoordinate2D(latitude: entity.latitude, longitude: entity.longitude)
            : nil
    }
}
