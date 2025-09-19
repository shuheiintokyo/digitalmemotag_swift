// MARK: - CloudDataManager.swift (Replace existing file with this)
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
    
    // MARK: - Initialization
    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        
        // Initial load
        Task {
            await loadItems()
            startPeriodicRefresh()
        }
    }
    
    // MARK: - Public Interface
    
    func loadItems() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        isLoading = true
        syncStatus = .syncing
        
        do {
            // 1. Try to load from cloud first
            let cloudItemsData = try await appwriteService.getAllItems()
            
            // 2. Convert to CloudItem objects and load messages
            var cloudItems: [CloudItem] = []
            
            for itemData in cloudItemsData {
                if var cloudItem = CloudItem.from(appwriteData: itemData) {
                    // Load messages for this item
                    let messagesData = try await appwriteService.getMessages(for: cloudItem.itemId)
                    let messages = messagesData.compactMap { data in
                        CloudMessage.from(appwriteData: data)
                    }.sorted { $0.createdAt > $1.createdAt }
                    
                    cloudItem.messages = messages
                    cloudItems.append(cloudItem)
                }
            }
            
            // 3. Update local cache
            await updateLocalCache(with: cloudItems)
            
            // 4. Update UI
            items = cloudItems.sorted { $0.createdAt > $1.createdAt }
            isOnline = true
            syncStatus = .success
            lastError = nil
            lastSyncTime = Date()
            
            print("✅ Loaded \(cloudItems.count) items from cloud")
            
        } catch {
            // Fallback to local cache if cloud fails
            await loadFromLocalCache()
            isOnline = false
            syncStatus = .offline
            lastError = error.localizedDescription
            
            print("⚠️ Failed to load from cloud, using local cache: \(error)")
        }
        
        isLoading = false
        isSyncing = false
    }
    
    func createItem(name: String, location: String) async -> CloudItem? {
        guard !isSyncing else { return nil }
        
        isSyncing = true
        isLoading = true
        syncStatus = .syncing
        
        // Generate unique ID
        let itemId = generateItemId()
        
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
    
    func addMessage(to item: CloudItem, message: String, userName: String = "匿名", type: MessageType = .general) async -> Bool {
        guard !isSyncing else { return false }
        
        syncStatus = .syncing
        
        do {
            // 1. Post message to cloud first
            let messageId = try await appwriteService.postMessage(
                itemId: item.itemId,
                message: message,
                userName: userName,
                msgType: type.rawValue
            )
            
            // 2. Create CloudMessage object
            let newMessage = CloudMessage(
                id: messageId,
                itemId: item.itemId,
                message: message,
                userName: userName,
                messageType: type,
                createdAt: Date()
            )
            
            // 3. Update item status if needed
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
                
                // Update status in cloud
                try await appwriteService.updateItemStatus(itemId: item.itemId, status: newStatus.rawValue)
                
                // Update local item
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].status = newStatus
                    items[index].updatedAt = Date()
                }
            }
            
            // 4. Add message to local item
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].messages.insert(newMessage, at: 0)
            }
            
            isOnline = true
            syncStatus = .success
            lastError = nil
            lastSyncTime = Date()
            
            print("✅ Added message to cloud for item: \(item.itemId)")
            return true
            
        } catch {
            isOnline = false
            syncStatus = .error(error.localizedDescription)
            lastError = "メッセージ追加に失敗: \(error.localizedDescription)"
            
            print("❌ Failed to add message to cloud: \(error)")
            return false
        }
    }
    
    func loadMessages(for item: CloudItem) async {
        do {
            let messagesData = try await appwriteService.getMessages(for: item.itemId)
            
            let messages = messagesData.compactMap { data in
                CloudMessage.from(appwriteData: data)
            }.sorted { $0.createdAt > $1.createdAt }
            
            // Update local item
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].messages = messages
            }
            
            print("✅ Loaded \(messages.count) messages for item: \(item.itemId)")
            
        } catch {
            print("❌ Failed to load messages: \(error)")
            lastError = "メッセージ読み込みに失敗: \(error.localizedDescription)"
        }
    }
    
    func deleteItem(_ item: CloudItem) async -> Bool {
        do {
            // Delete from cloud (you'll need to add this method to AppwriteService)
            // try await appwriteService.deleteItem(itemId: item.itemId)
            
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
        await loadItems()
    }
    
    func findItem(byId itemId: String) -> CloudItem? {
        return items.first { $0.itemId == itemId }
    }
    
    // MARK: - Local Caching (for offline support)
    
    private func updateLocalCache(with cloudItems: [CloudItem]) async {
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
        let cachedItems = Item.fetchAllItems(in: viewContext)
        
        let cloudItems = cachedItems.compactMap { item -> CloudItem? in
            return item.toCloudItem()
        }
        
        items = cloudItems
        
        print("📱 Loaded \(cloudItems.count) items from local cache")
    }
    
    // MARK: - Periodic Refresh
    
    private func startPeriodicRefresh() {
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
