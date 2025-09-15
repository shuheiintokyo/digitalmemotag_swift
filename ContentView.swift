import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("製品一覧")
                }
                .tag(0)
            
            QRScannerView()
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("QRスキャン")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Models and Core Data Setup
import Foundation
import CoreData

// MARK: - PersistenceController.swift
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
        container = NSPersistentContainer(name: "DataModel")
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

// MARK: - ItemStatus.swift
enum ItemStatus: String, CaseIterable {
    case working = "Working"
    case completed = "Completed"
    case delayed = "Delayed"
    case problem = "Problem"
    
    var color: Color {
        switch self {
        case .working: return .blue
        case .completed: return .green
        case .delayed: return .yellow
        case .problem: return .red
        }
    }
    
    var localizedString: String {
        switch self {
        case .working: return "作業中"
        case .completed: return "完了"
        case .delayed: return "遅延"
        case .problem: return "問題"
        }
    }
}

// MARK: - MessageType.swift
enum MessageType: String, CaseIterable {
    case general = "general"
    case blue = "blue"
    case green = "green"
    case yellow = "yellow"
    case red = "red"
    
    var buttonText: String {
        switch self {
        case .general: return ""
        case .blue: return "作業を開始しました"
        case .green: return "作業を完了しました"
        case .yellow: return "作業に遅れが生じています"
        case .red: return "問題が発生しました。"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}

// MARK: - Extensions for Core Data
extension Item {
    var statusEnum: ItemStatus {
        get { ItemStatus(rawValue: status ?? "Working") ?? .working }
        set { status = newValue.rawValue }
    }
    
    var hasNewMessages: Bool {
        guard let messages = messages?.allObjects as? [Message] else { return false }
        return messages.contains { message in
            guard let lastViewed = UserDefaults.standard.object(forKey: "lastViewed_\(itemId ?? "")") as? Date,
                  let messageDate = message.createdAt else { return false }
            return messageDate > lastViewed
        }
    }
    
    func markAsViewed() {
        UserDefaults.standard.set(Date(), forKey: "lastViewed_\(itemId ?? "")")
    }
}

extension Message {
    var messageTypeEnum: MessageType {
        get { MessageType(rawValue: msgType ?? "general") ?? .general }
        set { msgType = newValue.rawValue }
    }
}

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
