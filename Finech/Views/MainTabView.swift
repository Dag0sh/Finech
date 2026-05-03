import SwiftUI

struct MainTabView: View {
    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(ExchangeRateViewModel.self) var rateVM

    var body: some View {
        TabView {
            Tab("Обзор", systemImage: "house.fill") {
                DashboardView()
            }
            Tab("Транзакции", systemImage: "list.bullet.rectangle") {
                TransactionListView()
            }
            Tab("Статистика", systemImage: "chart.pie.fill") {
                StatisticsView()
            }
            Tab("Карта", systemImage: "map.fill") {
                TransactionMapView()
            }
        }
        .alert("Ошибка", isPresented: Bindable(transactionVM).showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transactionVM.alertMessage ?? "")
        }
    }
}
