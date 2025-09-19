//
//  CoreData+Extensions.swift
//  digitalmemotag
//
//  Extensions for CoreData entities (Fixed - removed conflicting fetchRequest methods)
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Item Extensions

extension Item {
    var statusEnum: ItemStatus {
        get {
            return ItemStatus(rawValue: status ?? "Working") ?? .working
        }
        set {
            status = newValue.rawValue
        }
    }
    
    var hasNewMessages: Bool {
        // In a real implementation, you'd track the last viewed time
        // For now, we'll return true if there are any messages
        return (messages?.count ?? 0) > 0
    }
    
    var messageCount: Int {
        return messages?.count ?? 0
    }
    
    var sortedMessages: [Message] {
        let messageArray = messages?.allObjects as? [Message] ?? []
        return messageArray.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
    
    func markAsViewed() {
        // Update the last viewed time
        // In a real implementation, you'd store this timestamp
        self.updatedAt = Date()
        
        // Save context
        do {
            try managedObjectContext?.save()
        } catch {
            print("Failed to save viewed state: \(error)")
        }
    }
    
    // Convert to CloudItem for Appwrite sync
    func toCloudItem() -> CloudItem? {
        guard let itemId = self.itemId,
              let name = self.name else { return nil }
        
        let messages = sortedMessages.compactMap { $0.toCloudMessage() }
        
        return CloudItem(
            id: self.id?.uuidString ?? UUID().uuidString,
            itemId: itemId,
            name: name,
            location: self.location ?? "",
            status: self.statusEnum,
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date(),
            messages: messages
        )
    }
    
    // Update from CloudItem
    func updateFrom(cloudItem: CloudItem) {
        self.name = cloudItem.name
        self.location = cloudItem.location
        self.status = cloudItem.status.rawValue
        self.updatedAt = cloudItem.updatedAt
    }
    
    // Static helper methods (using different names to avoid conflicts)
    static func fetchAllItems(in context: NSManagedObjectContext) -> [Item] {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch items: \(error)")
            return []
        }
    }
    
    static func fetchItem(byItemId itemId: String, in context: NSManagedObjectContext) -> Item? {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(format: "itemId == %@", itemId)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch item with ID \(itemId): \(error)")
            return nil
        }
    }
}

// MARK: - Message Extensions

extension Message {
    var messageTypeEnum: MessageType {
        get {
            return MessageType(rawValue: msgType ?? "general") ?? .general
        }
        set {
            msgType = newValue.rawValue
        }
    }
    
    var isStatusUpdate: Bool {
        return messageTypeEnum != .general
    }
    
    var formattedDate: String {
        guard let date = createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var isSystemMessage: Bool {
        return userName == "システム"
    }
    
    // Convert to CloudMessage for Appwrite sync
    func toCloudMessage() -> CloudMessage? {
        guard let message = self.message,
              let userName = self.userName,
              let itemId = self.itemId else { return nil }
        
        return CloudMessage(
            id: self.id?.uuidString ?? UUID().uuidString,
            itemId: itemId,
            message: message,
            userName: userName,
            messageType: self.messageTypeEnum,
            createdAt: self.createdAt ?? Date()
        )
    }
    
    // Update from CloudMessage
    func updateFrom(cloudMessage: CloudMessage) {
        self.message = cloudMessage.message
        self.userName = cloudMessage.userName
        self.msgType = cloudMessage.messageType.rawValue
        self.createdAt = cloudMessage.createdAt
    }
    
    // Static helper methods
    static func fetchMessages(forItemId itemId: String, in context: NSManagedObjectContext) -> [Message] {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "itemId == %@", itemId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch messages for item \(itemId): \(error)")
            return []
        }
    }
}

// MARK: - CloudItem Extensions

extension CloudItem {
    // Convert to CoreData Item
    func toCoreDataItem(context: NSManagedObjectContext) -> Item {
        let item = Item(context: context)
        item.id = UUID(uuidString: self.id) ?? UUID()
        item.itemId = self.itemId
        item.name = self.name
        item.location = self.location
        item.status = self.status.rawValue
        item.createdAt = self.createdAt
        item.updatedAt = self.updatedAt
        
        // Add messages
        for cloudMessage in self.messages {
            let message = cloudMessage.toCoreDataMessage(context: context)
            message.item = item
        }
        
        return item
    }
    
    // Update existing CoreData item
    func updateCoreDataItem(_ item: Item) {
        item.name = self.name
        item.location = self.location
        item.status = self.status.rawValue
        item.updatedAt = self.updatedAt
    }
}

// MARK: - CloudMessage Extensions

extension CloudMessage {
    // Convert to CoreData Message
    func toCoreDataMessage(context: NSManagedObjectContext) -> Message {
        let message = Message(context: context)
        message.id = UUID(uuidString: self.id) ?? UUID()
        message.itemId = self.itemId
        message.message = self.message
        message.userName = self.userName
        message.msgType = self.messageType.rawValue
        message.createdAt = self.createdAt
        
        return message
    }
    
    // Update existing CoreData message
    func updateCoreDataMessage(_ message: Message) {
        message.message = self.message
        message.userName = self.userName
        message.msgType = self.messageType.rawValue
        message.createdAt = self.createdAt
    }
}

// MARK: - Helper Functions

extension NSManagedObjectContext {
    func saveIfNeeded() {
        guard hasChanges else { return }
        
        do {
            try save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}
