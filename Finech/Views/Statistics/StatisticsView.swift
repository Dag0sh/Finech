import SwiftUI
import Charts

struct StatisticsView: View {
    @Environment(TransactionViewModel.self) var vm

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    incomeExpenseChart
                    if !vm.expensesByCategory.isEmpty {
                        categoryPieChart
                        categoryBarChart
                    } else {
                        ContentUnavailableView(
                            "Нет данных",
                            systemImage: "chart.pie",
                            description: Text("Добавьте транзакции для отображения статистики")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Статистика")
        }
    }

    // MARK: - Charts

    private var incomeExpenseChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Доходы и расходы")
                .font(.headline)

            Chart {
                BarMark(
                    x: .value("Тип", "Доходы"),
                    y: .value("Сумма", vm.totalIncome)
                )
                .foregroundStyle(.green.gradient)
                .cornerRadius(8)

                BarMark(
                    x: .value("Тип", "Расходы"),
                    y: .value("Сумма", vm.totalExpense)
                )
                .foregroundStyle(.red.gradient)
                .cornerRadius(8)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: "RUB").precision(.fractionLength(0)))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var categoryPieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Расходы по категориям")
                .font(.headline)

            Chart(vm.expensesByCategory, id: \.category) { item in
                SectorMark(
                    angle: .value("Сумма", item.amount),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .cornerRadius(6)
                .foregroundStyle(by: .value("Категория", item.category.rawValue))
            }
            .frame(height: 220)
            .chartLegend(position: .bottom, alignment: .center)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var categoryBarChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Топ расходов")
                .font(.headline)

            Chart(vm.expensesByCategory.prefix(6), id: \.category) { item in
                BarMark(
                    x: .value("Сумма", item.amount),
                    y: .value("Категория", item.category.rawValue)
                )
                .foregroundStyle(by: .value("Категория", item.category.rawValue))
                .cornerRadius(6)
                .annotation(position: .trailing) {
                    Text(item.amount, format: .currency(code: "RUB").precision(.fractionLength(0)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(vm.expensesByCategory.prefix(6).count) * 44)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
