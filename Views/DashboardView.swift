// MARK: - DashboardView.swift
import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.createdAt, ascending: false)],
        animation: .default)
    private var items: FetchedResults<Item>
    
    @StateObject private var itemManager: ItemManager
    @State private var showingAddItem = false
    @State private var searchText = ""
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._itemManager = StateObject(wrappedValue: ItemManager(context: context))
    }
    
    var filteredItems: [Item] {
        if searchText.isEmpty {
            return Array(items)
        } else {
            return items.filter { item in
                item.name?.localizedCaseInsensitiveContains(searchText) == true ||
                item.itemId?.localizedCaseInsensitiveContains(searchText) == true ||
                item.location?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                ItemSearchField(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Items List
                if filteredItems.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(filteredItems, id: \.id) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                ItemRowView(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("製品一覧")
            .navigationBarItems(trailing:
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
                    .environmentObject(itemManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredItems[$0] }.forEach(itemManager.deleteItem)
        }
    }
}
