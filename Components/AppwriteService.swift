import Appwrite
import Foundation

class AppwriteService: ObservableObject {
    static let shared = AppwriteService()
    
    let client = Client()
    let databases: Databases
    
    // FIXED: Use the correct database ID from your Appwrite dashboard
    let databaseId = "68cba0e00372afe7c23"
    let itemsCollectionId = "items"
    let messagesCollectionId = "messages"
    
    @Published var isConnected = false
    @Published var lastError: String?
    
    private init() {
        client
            .setEndpoint("https://sfo.cloud.appwrite.io/v1")
            .setProject("68cba284000aabe9c076")
        
        databases = Databases(client)
        
        // Test connection on initialization
        Task {
            await testConnection()
        }
    }
    
    // MARK: - Connection Testing
    func testConnection() async {
        do {
            // FIXED: Use listDocuments instead of databases.get() which doesn't exist
            _ = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                queries: [Query.limit(1)]
            )
            await MainActor.run {
                self.isConnected = true
                self.lastError = nil
                print("✅ Successfully connected to Appwrite database")
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.lastError = error.localizedDescription
                print("❌ Failed to connect to Appwrite: \(error)")
            }
        }
    }
    
    // MARK: - Items Functions
    func createItem(itemId: String, name: String, location: String, status: String = "Working") async throws -> String {
        let data: [String: Any] = [
            "item_id": itemId,
            "name": name,
            "location": location,
            "status": status
        ]
        
        let document = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: itemsCollectionId,
            documentId: ID.unique(),
            data: data
        )
        
        print("✅ Created item in Appwrite: \(itemId)")
        return document.id
    }
    
    func getItem(itemId: String) async throws -> [String: Any]? {
        let response = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: itemsCollectionId,
            queries: [
                Query.equal("item_id", value: itemId),
                Query.limit(1)
            ]
        )
        
        return response.documents.first?.data
    }
    
    func getAllItems() async throws -> [[String: Any]] {
        let response = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: itemsCollectionId,
            queries: [
                Query.orderDesc("$createdAt")
            ]
        )
        
        return response.documents.map { $0.data }
    }
    
    func updateItemStatus(itemId: String, status: String) async throws {
        // First, find the document ID
        let items = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: itemsCollectionId,
            queries: [Query.equal("item_id", value: itemId)]
        )
        
        guard let document = items.documents.first else {
            throw AppError.itemNotFound
        }
        
        _ = try await databases.updateDocument(
            databaseId: databaseId,
            collectionId: itemsCollectionId,
            documentId: document.id,
            data: ["status": status]
        )
        
        print("✅ Updated item status in Appwrite: \(itemId) -> \(status)")
    }
    
    // MARK: - Messages Functions
    func getMessages(for itemId: String) async throws -> [[String: Any]] {
        let response = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: messagesCollectionId,
            queries: [
                Query.equal("item_id", value: itemId),
                Query.orderDesc("$createdAt")
            ]
        )
        
        return response.documents.map { $0.data }
    }
    
    func postMessage(itemId: String, message: String, userName: String = "匿名", msgType: String = "general") async throws -> String {
        let data: [String: Any] = [
            "item_id": itemId,
            "message": message,
            "user_name": userName,
            "msg_type": msgType
        ]
        
        let document = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: messagesCollectionId,
            documentId: ID.unique(),
            data: data
        )
        
        print("✅ Posted message to Appwrite for item: \(itemId)")
        return document.id
    }
    
    func deleteMessage(documentId: String) async throws {
        try await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: messagesCollectionId,
            documentId: documentId
        )
        
        print("✅ Deleted message from Appwrite: \(documentId)")
    }
    
    // MARK: - Sync Functions
    func syncItemToAppwrite(item: Item) async throws {
        guard let itemId = item.itemId,
              let name = item.name else {
            throw AppError.coreDataError("Invalid item data")
        }
        
        // Check if item exists in Appwrite
        if let _ = try? await getItem(itemId: itemId) {
            // Update existing item
            try await updateItemStatus(itemId: itemId, status: item.status ?? "Working")
        } else {
            // Create new item
            _ = try await createItem(
                itemId: itemId,
                name: name,
                location: item.location ?? "",
                status: item.status ?? "Working"
            )
        }
    }
    
    // MARK: - Basic Database Test (for debugging)
    func testDatabaseAccess() async -> Bool {
        do {
            _ = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                queries: [Query.limit(1)]
            )
            return true
        } catch {
            print("❌ Database access test failed: \(error)")
            return false
        }
    }
    
    func testCollectionAccess(collectionId: String) async -> Bool {
        do {
            _ = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: collectionId,
                queries: [Query.limit(1)]
            )
            return true
        } catch {
            print("❌ Collection access test failed for \(collectionId): \(error)")
            return false
        }
    }
}
