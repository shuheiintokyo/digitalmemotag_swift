//
//  PersistenceController.swift
//  digitalmemotag
//

import SwiftUI
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Add sample data for preview
        let sampleItem = Item(context: viewContext)
        sampleItem.id = UUID()
        sampleItem.itemId = "20250115-01"
        sampleItem.name = "サンプル製品"
        sampleItem.location = "倉庫A"
        sampleItem.status = "Working"
        sampleItem.createdAt = Date()
        sampleItem.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "digitalmemotag")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
