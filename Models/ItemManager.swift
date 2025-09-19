// MARK: - ItemManager.swift (Business Logic with Appwrite Sync)
import Foundation
import CoreData

class ItemManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    private let appwriteService = AppwriteService.shared
    
    @Published var isSyncing = false
    @Published var lastSyncError: String?
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    func generateItemId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        
        // Get today's items count
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(format: "itemId BEGINSWITH %@", dateString)
        
        let todayItemsCount = (try? viewContext.count(for: request)) ?? 0
        let sequenceNumber = String(format: "%02d", todayItemsCount + 1)
        
        return "\(dateString)-\(sequenceNumber)"
    }
    
    func createItem(name: String, location: String) {
        let newItem = Item(context: viewContext)
        newItem.id = UUID()
        newItem.itemId = generateItemId()
        newItem.name = name
        newItem.location = location
        newItem.statusEnum = .working
        newItem.createdAt = Date()
        newItem.updatedAt = Date()
        
        // Save to Core Data first
        save()
        
        // Sync to Appwrite in background
        Task {
            await syncItemToAppwrite(newItem)
        }
    }
    
    func deleteItem(_ item: Item) {
        // Note: You might want to implement Appwrite deletion too
        viewContext.delete(item)
        save()
    }
    
    func addMessage(to item: Item, message: String, userName: String = "匿名", type: MessageType = .general) {
        let newMessage = Message(context: viewContext)
        newMessage.id = UUID()
        newMessage.itemId = item.itemId
        newMessage.message = message
        newMessage.userName = userName
        newMessage.messageTypeEnum = type
        newMessage.createdAt = Date()
        newMessage.item = item
        
        // Update item status based on message type
        if type != .general {
            switch type {
            case .blue: item.statusEnum = .working
            case .green: item.statusEnum = .completed
            case .yellow: item.statusEnum = .delayed
            case .red: item.statusEnum = .problem
            default: break
            }
            item.updatedAt = Date()
        }
        
        // Save to Core Data first
        save()
        
        // Sync to Appwrite in background
        Task {
            await syncMessageToAppwrite(newMessage)
            if type != .general {
                await syncItemToAppwrite(item)
            }
        }
    }
    
    func deleteMessage(_ message: Message) {
        viewContext.delete(message)
        save()
        
        // Note: You might want to implement Appwrite message deletion too
    }
    
    // MARK: - Sync Functions
    
    @MainActor
    private func syncItemToAppwrite(_ item: Item) async {
        guard let itemId = item.itemId,
              let name = item.name else {
            print("❌ Cannot sync item: missing required fields")
            return
        }
        
        isSyncing = true
        
        do {
            // Check if item exists in Appwrite
            if let _ = try? await appwriteService.getItem(itemId: itemId) {
                // Update existing item
                try await appwriteService.updateItemStatus(
                    itemId: itemId,
                    status: item.status ?? "Working"
                )
                print("✅ Updated item in Appwrite: \(itemId)")
            } else {
                // Create new item
                _ = try await appwriteService.createItem(
                    itemId: itemId,
                    name: name,
                    location: item.location ?? "",
                    status: item.status ?? "Working"
                )
                print("✅ Created item in Appwrite: \(itemId)")
            }
            
            lastSyncError = nil
            
        } catch {
            print("❌ Failed to sync item to Appwrite: \(error)")
            lastSyncError = "アイテムの同期に失敗: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
    
    @MainActor
    private func syncMessageToAppwrite(_ message: Message) async {
        guard let itemId = message.itemId,
              let messageText = message.message,
              let userName = message.userName,
              let msgType = message.msgType else {
            print("❌ Cannot sync message: missing required fields")
            return
        }
        
        do {
            _ = try await appwriteService.postMessage(
                itemId: itemId,
                message: messageText,
                userName: userName,
                msgType: msgType
            )
            print("✅ Synced message to Appwrite for item: \(itemId)")
        } catch {
            print("❌ Failed to sync message to Appwrite: \(error)")
            lastSyncError = "メッセージの同期に失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Fetch and Sync from Appwrite
    
    func syncFromAppwrite() async {
        await MainActor.run {
            isSyncing = true
        }
        
        do {
            // Get all items from Appwrite
            let appwriteItems = try await appwriteService.getAllItems()
            
            await MainActor.run {
                for itemData in appwriteItems {
                    syncAppwriteItemToLocal(itemData: itemData)
                }
                
                save()
                isSyncing = false
                lastSyncError = nil
                print("✅ Synced \(appwriteItems.count) items from Appwrite")
            }
            
        } catch {
            await MainActor.run {
                isSyncing = false
                lastSyncError = "Appwriteからの同期に失敗: \(error.localizedDescription)"
                print("❌ Failed to sync from Appwrite: \(error)")
            }
        }
    }
    
    private func syncAppwriteItemToLocal(itemData: [String: Any]) {
        guard let itemId = itemData["item_id"] as? String else { return }
        
        // Check if item already exists locally
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(format: "itemId == %@", itemId)
        
        do {
            let existingItems = try viewContext.fetch(request)
            let item: Item
            
            if let existingItem = existingItems.first {
                // Update existing item
                item = existingItem
            } else {
                // Create new item
                item = Item(context: viewContext)
                item.id = UUID()
                item.itemId = itemId
                item.createdAt = Date()
            }
            
            // Update item properties
            item.name = itemData["name"] as? String ?? "Unknown"
            item.location = itemData["location"] as? String ?? ""
            item.status = itemData["status"] as? String ?? "Working"
            item.updatedAt = Date()
            
        } catch {
            print("❌ Error syncing item \(itemId): \(error)")
        }
    }
    
    func syncMessagesForItem(_ item: Item) async {
        guard let itemId = item.itemId else { return }
        
        do {
            let appwriteMessages = try await appwriteService.getMessages(for: itemId)
            
            await MainActor.run {
                for messageData in appwriteMessages {
                    syncAppwriteMessageToLocal(messageData: messageData, item: item)
                }
                
                save()
                print("✅ Synced \(appwriteMessages.count) messages for item: \(itemId)")
            }
            
        } catch {
            print("❌ Failed to sync messages for item \(itemId): \(error)")
        }
    }
    
    private func syncAppwriteMessageToLocal(messageData: [String: Any], item: Item) {
        // For simplicity, we'll create new messages (you might want to implement duplicate checking)
        let message = Message(context: viewContext)
        message.id = UUID()
        message.itemId = item.itemId
        message.message = messageData["message"] as? String ?? ""
        message.userName = messageData["user_name"] as? String ?? "Unknown"
        message.msgType = messageData["msg_type"] as? String ?? "general"
        message.createdAt = Date() // You might want to parse the actual creation date
        message.item = item
    }
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("❌ Error saving context: \(error)")
            lastSyncError = "ローカル保存エラー: \(error.localizedDescription)"
        }
    }
}
