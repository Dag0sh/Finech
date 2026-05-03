import SwiftUI

struct TransactionListView: View {
    @Environment(TransactionViewModel.self) var vm
    @State private var showAdd = false
    @State private var editingTransaction: Transaction?

    private var grouped: [(date: Date, items: [Transaction])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: vm.filtered) { cal.startOfDay(for: $0.date) }
        return dict.map { (date: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.filtered.isEmpty {
                    ContentUnavailableView(
                        vm.searchText.isEmpty ? "Нет транзакций" : "Ничего не найдено",
                        systemImage: vm.searchText.isEmpty ? "tray" : "magnifyingglass",
                        description: vm.searchText.isEmpty ? Text("Нажмите + чтобы добавить") : nil
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                            ForEach(grouped, id: \.date) { group in
                                Section {
                                    VStack(spacing: 0) {
                                        ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, transaction in
                                            TransactionRowView(transaction: transaction)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .contentShape(Rectangle())
                                                .contextMenu {
                                                    Button("Изменить", systemImage: "pencil") {
                                                        editingTransaction = transaction
                                                    }
                                                    Button("Удалить", systemImage: "trash", role: .destructive) {
                                                        vm.delete(transaction)
                                                    }
                                                }

                                            if idx < group.items.count - 1 {
                                                Divider().padding(.leading, 70)
                                            }
                                        }
                                    }
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                } header: {
                                    DateSectionHeader(date: group.date)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Транзакции")
            .searchable(text: Bindable(vm).searchText, prompt: "Поиск по категории или заметке")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Добавить", systemImage: "plus") { showAdd = true }
                }
            }
            .sheet(isPresented: $showAdd) { AddTransactionView() }
            .sheet(item: $editingTransaction) { AddTransactionView(editingTransaction: $0) }
        }
    }
}

private struct DateSectionHeader: View {
    let date: Date

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Сегодня" }
        if cal.isDateInYesterday(date) { return "Вчера" }
        return date.formatted(.dateTime.day().month(.wide).year())
    }

    var body: some View {
        Text(label)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
