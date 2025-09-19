// MARK: - CloudDataManager.swift (Replace ItemManager)
import Foundation
import CoreData
import Appwrite
import SwiftUI

@MainActor
class CloudDataManager: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [CloudItem] = []
    @Published var isLoading = false
    @Published var isOnline = true
    @Published var lastError: String?
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Private Properties
    private let appwriteService = AppwriteService.shared
    private let viewContext: NSManagedObjectContext
    private var refreshTimer: Timer?
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case offline
        case error(String)
        
        var displayText: String {
            switch self {
            case .idle: return "待機中"
            case .syncing: return "同期中..."
            case .success: return "同期完了"
            case .offline: return "オフライン"
            case .error(let message): return "エラー: \(message)"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .syncing: return .blue
            case .success: return .green
            case .offline: return .orange
            case .error: return .red
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        startPeriodicRefresh()
        
        // Initial load
        Task {
            await loadItems()
        }
    }
    
    // MARK: - Cloud-First Operations
    
    func loadItems() async {
        isLoading = true
        syncStatus = .syncing
        
        do {
            // 1. Try to load from cloud first
            let cloudItemsData = try await appwriteService.getAllItems()
            
            // 2. Convert to CloudItem objects
            let cloudItems = cloudItemsData.compactMap { data in
                CloudItem.from(appwriteData: data)
            }
            
            // 3. Update local cache
            await updateLocalCache(with: cloudItems)
            
            // 4. Update UI
            items = cloudItems.sorted { $0.createdAt > $1.createdAt }
            isOnline = true
            syncStatus = .success
            lastError = nil
            
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
    }
    
    func createItem(name: String, location: String) async -> CloudItem? {
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
            
            print("✅ Created item in cloud: \(itemId)")
            return newItem
            
        } catch {
            isOnline = false
            syncStatus = .error(error.localizedDescription)
            lastError = "アイテム作成に失敗: \(error.localizedDescription)"
            
            print("❌ Failed to create item in cloud: \(error)")
            return nil
        }
        
        isLoading = false
    }
    
    func addMessage(to item: CloudItem, message: String, userName: String = "匿名", type: MessageType = .general) async -> Bool {
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
            // Delete from cloud first
            // Note: You'll need to add a delete method to AppwriteService
            // try await appwriteService.deleteItem(itemId: item.itemId)
            
            // Remove from local array
            items.removeAll { $0.id == item.id }
            
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
    
    private func loadFromLocalCache() async {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.createdAt, ascending: false)]
        
        do {
            let cachedItems = try viewContext.fetch(request)
            
            let cloudItems = cachedItems.compactMap { item -> CloudItem? in
                guard let itemId = item.itemId,
                      let name = item.name else { return nil }
                
                let messages = (item.messages?.allObjects as? [Message])?.compactMap { message -> CloudMessage? in
                    guard let messageText = message.message,
                          let userName = message.userName,
                          let msgType = message.msgType else { return nil }
                    
                    return CloudMessage(
                        id: message.id?.uuidString ?? UUID().uuidString,
                        itemId: message.itemId ?? "",
                        message: messageText,
                        userName: userName,
                        messageType: MessageType(rawValue: msgType) ?? .general,
                        createdAt: message.createdAt ?? Date()
                    )
                } ?? []
                
                return CloudItem(
                    id: item.id?.uuidString ?? UUID().uuidString,
                    itemId: itemId,
                    name: name,
                    location: item.location ?? "",
                    status: ItemStatus(rawValue: item.status ?? "Working") ?? .working,
                    createdAt: item.createdAt ?? Date(),
                    updatedAt: item.updatedAt ?? Date(),
                    messages: messages.sorted { $0.createdAt > $1.createdAt }
                )
            }
            
            items = cloudItems
            
            print("📱 Loaded \(cloudItems.count) items from local cache")
            
        } catch {
            print("❌ Failed to load from local cache: \(error)")
        }
    }
    
    // MARK: - Periodic Refresh
    
    private func startPeriodicRefresh() {
        // Refresh every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
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

// MARK: - Cloud Data Models

struct CloudItem: Identifiable, Hashable {
    let id: String
    let itemId: String
    let name: String
    let location: String
    var status: ItemStatus
    let createdAt: Date
    var updatedAt: Date
    var messages: [CloudMessage]
    
    static func from(appwriteData: [String: Any]) -> CloudItem? {
        guard let id = appwriteData["$id"] as? String,
              let itemId = appwriteData["item_id"] as? String,
              let name = appwriteData["name"] as? String else {
            return nil
        }
        
        let location = appwriteData["location"] as? String ?? ""
        let statusString = appwriteData["status"] as? String ?? "Working"
        let status = ItemStatus(rawValue: statusString) ?? .working
        
        // Parse dates (Appwrite format)
        let createdAt = parseAppwriteDate(appwriteData["$createdAt"] as? String) ?? Date()
        let updatedAt = parseAppwriteDate(appwriteData["$updatedAt"] as? String) ?? Date()
        
        return CloudItem(
            id: id,
            itemId: itemId,
            name: name,
            location: location,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messages: []
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CloudItem, rhs: CloudItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct CloudMessage: Identifiable, Hashable {
    let id: String
    let itemId: String
    let message: String
    let userName: String
    let messageType: MessageType
    let createdAt: Date
    
    static func from(appwriteData: [String: Any]) -> CloudMessage? {
        guard let id = appwriteData["$id"] as? String,
              let itemId = appwriteData["item_id"] as? String,
              let message = appwriteData["message"] as? String,
              let userName = appwriteData["user_name"] as? String else {
            return nil
        }
        
        let msgTypeString = appwriteData["msg_type"] as? String ?? "general"
        let messageType = MessageType(rawValue: msgTypeString) ?? .general
        
        let createdAt = parseAppwriteDate(appwriteData["$createdAt"] as? String) ?? Date()
        
        return CloudMessage(
            id: id,
            itemId: itemId,
            message: message,
            userName: userName,
            messageType: messageType,
            createdAt: createdAt
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Helper Functions

private func parseAppwriteDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    return formatter.date(from: dateString)
}
