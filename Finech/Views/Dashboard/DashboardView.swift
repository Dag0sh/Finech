import SwiftUI

struct DashboardView: View {
    @Environment(TransactionViewModel.self) var vm
    @Environment(ExchangeRateViewModel.self) var rateVM
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BalanceCardView(
                        balance: vm.balance,
                        income: vm.totalIncome,
                        expense: vm.totalExpense
                    )

                    if rateVM.isLoading && rateVM.rates.isEmpty {
                        RatesMiniWidgetSkeleton()
                    } else if !rateVM.rates.isEmpty {
                        let dashboardCurrencies = ["USD", "EUR", "GBP", "CNY"]
                        let widgetRates = dashboardCurrencies.compactMap { code in
                            rateVM.rates.first { $0.currency == code }
                        }
                        RatesMiniWidget(rates: widgetRates)
                    }

                    if !vm.transactions.isEmpty {
                        RecentTransactionsSection(transactions: Array(vm.transactions.prefix(5)))
                    } else {
                        ContentUnavailableView(
                            "Нет транзакций",
                            systemImage: "tray",
                            description: Text("Добавьте первую транзакцию")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Finech")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Добавить", systemImage: "plus") {
                        showAdd = true
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTransactionView()
            }
            .onChange(of: rateVM.rates) { _, newRates in
                let dict = Dictionary(uniqueKeysWithValues: newRates.map { ($0.currency, $0.rate) })
                vm.updateRates(dict)
            }
        }
    }
}

// MARK: - Subviews

private struct BalanceCardView: View {
    let balance: Double
    let income: Double
    let expense: Double

    var body: some View {
        VStack(spacing: 14) {
            Text("Общий баланс")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))

            Text(balance, format: .currency(code: "RUB"))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Divider()
                .overlay(.white.opacity(0.25))
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                SumItem(
                    label: "Доходы",
                    amount: income,
                    icon: "arrow.down.circle.fill",
                    iconColor: Color(red: 0.4, green: 0.95, blue: 0.6)
                )
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1, height: 44)
                SumItem(
                    label: "Расходы",
                    amount: expense,
                    icon: "arrow.up.circle.fill",
                    iconColor: Color(red: 1, green: 0.5, blue: 0.5)
                )
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.13, blue: 0.38),
                    Color(red: 0.08, green: 0.22, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

private struct SumItem: View {
    let label: String
    let amount: Double
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(amount, format: .currency(code: "RUB"))
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RatesMiniWidget: View {
    let rates: [ExchangeRate]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Курсы валют", systemImage: "arrow.2.squarepath")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(rates) { rate in
                    VStack(spacing: 4) {
                        Text(rate.flag)
                            .font(.title2)
                        Text("1 \(rate.currency)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        let rubPerUnit = rate.rate > 0 ? (1.0 / rate.rate) : 0
                        Text(rubPerUnit, format: .number.precision(.fractionLength(2)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("₽")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct RatesMiniWidgetSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Курсы валют", systemImage: "arrow.2.squarepath")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(.quaternary)
                            .frame(width: 32, height: 32)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(width: 36, height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(width: 28, height: 14)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(shimmer ? 0.4 : 1)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

private struct RecentTransactionsSection: View {
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Последние транзакции")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                    TransactionRowView(transaction: transaction)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    if index < transactions.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
