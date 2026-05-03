import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    @Environment(TransactionViewModel.self) var vm

    private var rubEquivalent: Double? {
        guard transaction.currency != "RUB",
              let rate = vm.exchangeRates[transaction.currency],
              rate > 0
        else { return nil }
        return transaction.amount / rate
    }

    var body: some View {
        HStack(spacing: 14) {
            CategoryIconView(category: transaction.category)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text((transaction.isIncome ? "+" : "−") + transaction.amount.formatted(.currency(code: transaction.currency)))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(transaction.isIncome ? Color.green : Color.primary)

                if let rub = rubEquivalent {
                    Text("≈ " + rub.formatted(.currency(code: "RUB")))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CategoryIconView: View {
    let category: TransactionCategory
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.color.swiftUIColor.gradient, in: RoundedRectangle(cornerRadius: size * 0.28))
    }
}
