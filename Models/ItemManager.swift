// MARK: - ItemManager.swift (Business Logic)
import Foundation
import CoreData

class ItemManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
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
        
        save()
    }
    
    func deleteItem(_ item: Item) {
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
        
        save()
    }
    
    func deleteMessage(_ message: Message) {
        viewContext.delete(message)
        save()
    }
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
