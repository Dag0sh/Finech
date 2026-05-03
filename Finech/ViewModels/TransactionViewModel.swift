import Foundation
import CoreData
import CoreLocation
import Observation

enum FinechError {
    static func overdraftMessage(available: Double) -> String {
        "Недостаточно средств. Доступно: \(available.formatted(.currency(code: "RUB")))"
    }
}

@Observable
final class TransactionViewModel {
    var transactions: [Transaction] = []
    var searchText = ""
    var alertMessage: String?
    var showAlert = false

    // base=RUB rates: rate["USD"] = сколько USD за 1 RUB (e.g. 0.011)
    var exchangeRates: [String: Double] = [:]

    func updateRates(_ rates: [String: Double]) {
        exchangeRates = rates
    }

    // Конвертирует сумму в валюте currency в рубли
    private func toRUB(_ amount: Double, currency: String) -> Double {
        guard currency != "RUB", let rate = exchangeRates[currency], rate > 0 else { return amount }
        return amount / rate
    }

    var balance: Double {
        transactions.reduce(0) { $0 + ($1.isIncome ? toRUB($1.amount, currency: $1.currency) : -toRUB($1.amount, currency: $1.currency)) }
    }

    var totalIncome: Double {
        transactions.filter(\.isIncome).reduce(0) { $0 + toRUB($1.amount, currency: $1.currency) }
    }

    var totalExpense: Double {
        transactions.filter { !$0.isIncome }.reduce(0) { $0 + toRUB($1.amount, currency: $1.currency) }
    }

    var filtered: [Transaction] {
        guard !searchText.isEmpty else { return transactions }
        return transactions.filter {
            $0.note.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var expensesByCategory: [(category: TransactionCategory, amount: Double)] {
        let expenses = transactions.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
    }

    var transactionsWithLocation: [Transaction] {
        transactions.filter { $0.coordinate != nil }
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.context) {
        self.context = context
        fetch()
    }

    // MARK: - Fetch

    func fetch() {
        let request = NSFetchRequest<TransactionEntity>(entityName: "TransactionEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        do {
            transactions = try context.fetch(request).map { Transaction(from: $0) }
        } catch {
            show(error.localizedDescription)
        }
    }

    // MARK: - Add

    func add(
        amount: Double,
        currency: String,
        type: TransactionType,
        category: TransactionCategory,
        note: String,
        coordinate: CLLocationCoordinate2D?
    ) {
        if type == .expense, currency == "RUB", amount > balance {
            show(FinechError.overdraftMessage(available: balance))
            return
        }

        let newTransaction = Transaction(
            id: UUID(),
            amount: amount,
            currency: currency,
            type: type,
            category: category,
            note: note,
            date: Date(),
            coordinate: coordinate
        )

        transactions.insert(newTransaction, at: 0)

        do {
            let entity = TransactionEntity(context: context)
            entity.id = newTransaction.id
            entity.amount = amount
            entity.currency = currency
            entity.type = type.rawValue
            entity.category = category.rawValue
            entity.note = note
            entity.date = newTransaction.date
            if let coord = coordinate {
                entity.latitude = coord.latitude
                entity.longitude = coord.longitude
                entity.hasLocation = true
            }
            try context.save()
        } catch {
            transactions.removeAll { $0.id == newTransaction.id }
            show(error.localizedDescription)
        }
    }

    // MARK: - Update

    func update(_ transaction: Transaction) {
        let request = NSFetchRequest<TransactionEntity>(entityName: "TransactionEntity")
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }

            if let idx = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[idx] = transaction
            }

            entity.amount = transaction.amount
            entity.currency = transaction.currency
            entity.type = transaction.type.rawValue
            entity.category = transaction.category.rawValue
            entity.note = transaction.note
            if let coord = transaction.coordinate {
                entity.latitude = coord.latitude
                entity.longitude = coord.longitude
                entity.hasLocation = true
            } else {
                entity.hasLocation = false
            }
            try context.save()
            fetch() // принудительный рефетч — гарантирует синхронизацию UI
        } catch {
            fetch()
            show(error.localizedDescription)
        }
    }

    // MARK: - Delete

    func delete(_ transaction: Transaction) {
        let request = NSFetchRequest<TransactionEntity>(entityName: "TransactionEntity")
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }
            transactions.removeAll { $0.id == transaction.id }
            context.delete(entity)
            try context.save()
        } catch {
            fetch()
            show(error.localizedDescription)
        }
    }

    func delete(at offsets: IndexSet, in list: [Transaction]) {
        offsets.map { list[$0] }.forEach(delete)
    }

    // MARK: - Private

    private func show(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
