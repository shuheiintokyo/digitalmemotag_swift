// MARK: - CloudDataManager.swift (Updated with better message handling)
import Foundation
import CoreData
import Appwrite
import SwiftUI

@MainActor
class CloudDataManager: ObservableObject {
    // MARK: - Singleton
    static let shared = CloudDataManager()
    
    // MARK: - Published Properties
    @Published var items: [CloudItem] = []
    @Published var isLoading = false
    @Published var isOnline = true
    @Published var lastError: String?
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date?
    
    // MARK: - Private Properties
    private let appwriteService = AppwriteService.shared
    private let viewContext: NSManagedObjectContext
    private var refreshTimer: Timer?
    private var isSyncing = false
    private var hasInitialLoad = false
    
    // MARK: - Initialization
    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        print("🏗️ CloudDataManager initialized")
    }
    
    // MARK: - Public Interface
    
    func initialize() async {
        guard !hasInitialLoad else { return }
        hasInitialLoad = true
        
        print("🚀 CloudDataManager starting initial load")
        await loadItems()
        startPeriodicRefresh()
    }
    
    func loadItems() async {
        guard !isSyncing else {
            print("⏳ Already syncing, skipping load request")
            return
        }
        
        isSyncing = true
        isLoading = true
        syncStatus = .syncing
        
        print("🔄 Starting data load from Appwrite...")
        
        do {
            // 1. Test connection first
            await appwriteService.testConnection()
            
            if !appwriteService.isConnected {
                throw AppwriteError.notConnected
            }
            
            // 2. Try to load from cloud
            let cloudItemsData = try await appwriteService.getAllItems()
            print("📦 Retrieved \(cloudItemsData.count) items from Appwrite")
            
            // 3. Convert to CloudItem objects and load messages
            var cloudItems: [CloudItem] = []
            
            for (index, itemData) in cloudItemsData.enumerated() {
                print("🔄 Processing item \(index + 1)/\(cloudItemsData.count)")
                
                if var cloudItem = CloudItem.from(appwriteData: itemData) {
                    // Load messages for this item
                    do {
                        let messagesData = try await appwriteService.getMessages(for: cloudItem.itemId)
                        let messages = messagesData.compactMap { data in
                            CloudMessage.from(appwriteData: data)
                        }.sorted { $0.createdAt > $1.createdAt }
                        
                        cloudItem.messages = messages
                        cloudItems.append(cloudItem)
                        print("✅ Loaded item: \(cloudItem.name) with \(messages.count) messages")
                    } catch {
                        print("⚠️ Failed to load messages for item \(cloudItem.itemId): \(error)")
                        // Still add the item without messages
                        cloudItems.append(cloudItem)
                    }
                } else {
                    print("❌ Failed to parse item data: \(itemData)")
                }
            }
            
            // 4. Update local cache
            await updateLocalCache(with: cloudItems)
            
            // 5. Update UI
            items = cloudItems.sorted { $0.createdAt > $1.createdAt }
            isOnline = true
            syncStatus = .success
            lastError = nil
            lastSyncTime = Date()
            
            print("✅ Successfully loaded \(cloudItems.count) items from cloud")
            
        } catch {
            print("❌ Failed to load from cloud: \(error)")
            
            // Fallback to local cache if cloud fails
            await loadFromLocalCache()
            isOnline = false
            syncStatus = .offline
            lastError = error.localizedDescription
            
            print("📱 Fallback: Using local cache with \(items.count) items")
        }
        
        isLoading = false
        isSyncing = false
    }
    
    func createItem(name: String, location: String) async -> CloudItem? {
        guard !isSyncing else {
            print("⏳ Currently syncing, cannot create item")
            return nil
        }
        
        isSyncing = true
        isLoading = true
        syncStatus = .syncing
        
        // Generate unique ID
        let itemId = generateItemId()
        
        print("🆕 Creating new item: \(name) (ID: \(itemId))")
        
        do {
            // 1. Create in cloud first
            let documentId = try await appwriteService.createItem(
                itemId: itemId,
                name: name,
                location: location,
                status: "Working"
            )
            
            // 2. Create CloudItem object
            let newItem = CloudItem(
                id: documentId,
                itemId: itemId,
                name: name,
                location: location,
                status: .working,
                createdAt: Date(),
                updatedAt: Date(),
                messages: []
            )
            
            // 3. Add to local arrays immediately for UI responsiveness
            items.insert(newItem, at: 0)
            
            // 4. Cache locally
            await cacheItemLocally(newItem)
            
            isOnline = true
            syncStatus = .success
            lastError = nil
            lastSyncTime = Date()
            
            print("✅ Created item in cloud: \(itemId)")
            
            isSyncing = false
            isLoading = false
            return newItem
            
        } catch {
            isOnline = false
            syncStatus = .error(error.localizedDescription)
            lastError = "アイテム作成に失敗: \(error.localizedDescription)"
            
            print("❌ Failed to create item in cloud: \(error)")
            
            isSyncing = false
            isLoading = false
            return nil
        }
    }
    
    // MARK: - Enhanced Message Handling
    
    func addMessage(to item: CloudItem, message: String, userName: String = "匿名", type: MessageType = .general) async -> Bool {
        print("💬 DataManager adding message to item \(item.itemId): \(message)")
        
        do {
            // 1. Update item status if needed (before posting message)
            if type != .general {
                let newStatus: ItemStatus = {
                    switch type {
                    case .blue: return .working
                    case .green: return .completed
                    case .yellow: return .delayed
                    case .red: return .problem
                    default: return item.status
                    }
                }()
                
                // Update status in cloud first
                try await appwriteService.updateItemStatus(itemId: item.itemId, status: newStatus.rawValue)
                print("✅ Updated item status: \(newStatus.rawValue)")
                
                // Update local item status immediately
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].status = newStatus
                    items[index].updatedAt = Date()
                }
            }
            
            // 2. The message should already be posted to Appwrite by the caller
            // We just need to refresh the messages for this item
            await refreshMessagesForItem(item.itemId)
            
            syncStatus = .success
            lastError = nil
            lastSyncTime = Date()
            
            print("✅ Successfully handled message addition for item: \(item.itemId)")
            return true
            
        } catch {
            syncStatus = .error(error.localizedDescription)
            lastError = "メッセージ処理に失敗: \(error.localizedDescription)"
            
            print("❌ Failed to handle message addition: \(error)")
            return false
        }
    }
    
    func refreshMessagesForItem(_ itemId: String) async {
        print("🔄 Refreshing messages for item: \(itemId)")
        
        do {
            let messagesData = try await appwriteService.getMessages(for: itemId)
            let messages = messagesData.compactMap { data in
                CloudMessage.from(appwriteData: data)
            }.sorted { $0.createdAt > $1.createdAt }
            
            // Update the specific item's messages
            if let index = items.firstIndex(where: { $0.itemId == itemId }) {
                items[index].messages = messages
                print("✅ Refreshed \(messages.count) messages for item: \(itemId)")
            }
            
        } catch {
            print("❌ Failed to refresh messages for item \(itemId): \(error)")
        }
    }
    
    func loadMessages(for item: CloudItem) async {
        await refreshMessagesForItem(item.itemId)
    }
    
    func deleteItem(_ item: CloudItem) async -> Bool {
        print("🗑️ Deleting item: \(item.itemId)")
        
        do {
            // Delete from cloud
            try await appwriteService.deleteItem(itemId: item.itemId)
            
            // Remove from local array
            items.removeAll { $0.id == item.id }
            
            // Remove from local cache
            await removeFromLocalCache(item)
            
            print("✅ Deleted item: \(item.itemId)")
            return true
            
        } catch {
            print("❌ Failed to delete item: \(error)")
            lastError = "アイテム削除に失敗: \(error.localizedDescription)"
            return false
        }
    }
    
    func refreshData() async {
        print("🔄 Manual data refresh requested")
        await loadItems()
    }
    
    func findItem(byId itemId: String) -> CloudItem? {
        return items.first { $0.itemId == itemId }
    }
    
    // MARK: - Utility Methods
    
    func forceUIUpdate() {
        // Trigger a UI update by changing the items array reference
        let currentItems = items
        items = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.items = currentItems
        }
    }
    
    // MARK: - Local Caching (for offline support)
    
    private func updateLocalCache(with cloudItems: [CloudItem]) async {
        print("💾 Updating local cache with \(cloudItems.count) items")
        
        // Clear existing local cache
        let request: NSFetchRequest<NSFetchRequestResult> = Item.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try viewContext.execute(deleteRequest)
            
            // Add new items to cache
            for cloudItem in cloudItems {
                await cacheItemLocally(cloudItem)
            }
            
            try viewContext.save()
            print("✅ Local cache updated successfully")
            
        } catch {
            print("❌ Failed to update local cache: \(error)")
        }
    }
    
    private func cacheItemLocally(_ cloudItem: CloudItem) async {
        let item = Item(context: viewContext)
        item.id = UUID()
        item.itemId = cloudItem.itemId
        item.name = cloudItem.name
        item.location = cloudItem.location
        item.status = cloudItem.status.rawValue
        item.createdAt = cloudItem.createdAt
        item.updatedAt = cloudItem.updatedAt
        
        // Cache messages too
        for cloudMessage in cloudItem.messages {
            let message = Message(context: viewContext)
            message.id = UUID()
            message.itemId = cloudMessage.itemId
            message.message = cloudMessage.message
            message.userName = cloudMessage.userName
            message.msgType = cloudMessage.messageType.rawValue
            message.createdAt = cloudMessage.createdAt
            message.item = item
        }
    }
    
    private func removeFromLocalCache(_ cloudItem: CloudItem) async {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(format: "itemId == %@", cloudItem.itemId)
        
        do {
            let items = try viewContext.fetch(request)
            for item in items {
                viewContext.delete(item)
            }
            try viewContext.save()
        } catch {
            print("❌ Failed to remove from local cache: \(error)")
        }
    }
    
    private func loadFromLocalCache() async {
        print("📱 Loading from local cache...")
        
        let cachedItems = Item.fetchAllItems(in: viewContext)
        
        let cloudItems = cachedItems.compactMap { item -> CloudItem? in
            return item.toCloudItem()
        }
        
        items = cloudItems
        
        print("📱 Loaded \(cloudItems.count) items from local cache")
    }
    
    // MARK: - Periodic Refresh
    
    private func startPeriodicRefresh() {
        print("⏰ Starting periodic refresh (every 2 minutes)")
        
        // Refresh every 2 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { _ in
            Task {
                await self.refreshData()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func generateItemId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        
        // Use current items count for sequence number
        let todayItemsCount = items.filter { item in
            item.itemId.hasPrefix(dateString)
        }.count
        
        let sequenceNumber = String(format: "%02d", todayItemsCount + 1)
        return "\(dateString)-\(sequenceNumber)"
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
}

// MARK: - Convenience Extensions

extension CloudDataManager {
    var hasItems: Bool {
        return !items.isEmpty
    }
    
    var itemCount: Int {
        return items.count
    }
    
    func getItemsFiltered(by searchText: String) -> [CloudItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.itemId.localizedCaseInsensitiveContains(searchText) ||
                item.location.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}
