//
//  ItemManager.swift
//  digitalmemotag
//
//  Bridge between legacy views and new CloudDataManager
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class ItemManager: ObservableObject {
    static let shared = ItemManager()
    
    private let cloudDataManager = CloudDataManager.shared
    
    private init() {}
    
    func createItem(name: String, location: String) {
        Task {
            let _ = await cloudDataManager.createItem(name: name, location: location)
        }
    }
    
    func deleteItem(_ item: Item) {
        // Convert CoreData item to CloudItem and delete
        if let cloudItem = item.toCloudItem() {
            Task {
                let _ = await cloudDataManager.deleteItem(cloudItem)
            }
        }
    }
    
    func addMessage(to item: Item, message: String, userName: String, type: MessageType) {
        // Convert CoreData item to CloudItem and add message
        if let cloudItem = item.toCloudItem() {
            Task {
                let _ = await cloudDataManager.addMessage(to: cloudItem, message: message, userName: userName, type: type)
            }
        }
    }
}
