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
                // Logo Header
                LogoHeaderView()
                
                // Search Bar
                ItemSearchField(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Items List
                if filteredItems.isEmpty {
                    if items.isEmpty {
                        // Empty state with logo
                        EmptyStateViewWithLogo()
                    } else {
                        // No search results
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("検索結果がありません")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            
                            Text("別のキーワードで検索してください")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                    }
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
            .navigationTitle("")
            .navigationBarHidden(true)
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

// MARK: - Logo Header Component
struct LogoHeaderView: View {
    var body: some View {
        HStack {
            LogoView(size: .small, showTagline: false)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("製品一覧")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("FAST SERVICE")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .tracking(1)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .gray.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Enhanced Empty State with Logo
struct EmptyStateViewWithLogo: View {
    var body: some View {
        VStack(spacing: 30) {
            LogoView(size: .large, showTagline: true)
            
            VStack(spacing: 16) {
                Text("製品がありません")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Text("右上の + ボタンから新しい製品を追加してください")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Quick action hint
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(.blue)
                    Text("QRコードで簡単アクセス")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
