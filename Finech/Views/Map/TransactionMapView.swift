import SwiftUI
import MapKit

struct TransactionMapView: View {
    @Environment(TransactionViewModel.self) var vm
    @State private var selected: Transaction?
    @State private var position = MapCameraPosition.automatic

    var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selected) {
                ForEach(vm.transactionsWithLocation) { transaction in
                    // transactionsWithLocation фильтрует только с координатой — force unwrap безопасен
                    Annotation(
                        transaction.category.rawValue,
                        coordinate: transaction.coordinate!,
                        anchor: .bottom
                    ) {
                        MapPinView(transaction: transaction)
                            .onTapGesture { selected = transaction }
                    }
                    .tag(transaction)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
                MapScaleView()
            }
            .navigationTitle("Карта")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if vm.transactionsWithLocation.isEmpty {
                    emptyOverlay
                }
            }
            .sheet(item: $selected) { transaction in
                TransactionDetailSheet(transaction: transaction)
                    .presentationDetents([.height(220)])
            }
        }
    }

    private var emptyOverlay: some View {
        ContentUnavailableView(
            "Нет транзакций на карте",
            systemImage: "mappin.slash",
            description: Text("Добавьте транзакцию с геолокацией")
        )
        .background(.ultraThinMaterial)
    }
}

// MARK: - Subviews

private struct MapPinView: View {
    let transaction: Transaction

    private var pinColor: Color { transaction.category.color.swiftUIColor }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: 36, height: 36)
                Image(systemName: transaction.category.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundStyle(pinColor)
                .offset(y: -2)
        }
    }
}

private struct TransactionDetailSheet: View {
    let transaction: Transaction
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button("Закрыть", systemImage: "xmark.circle.fill") { dismiss() }
                    .foregroundStyle(.secondary)
            }

            TransactionRowView(transaction: transaction)

            if let coord = transaction.coordinate {
                Map(initialPosition: .camera(MapCamera(
                    centerCoordinate: coord,
                    distance: 800
                ))) {
                    Marker(transaction.category.rawValue, coordinate: coord)
                        .tint(transaction.category.color.swiftUIColor)
                }
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
