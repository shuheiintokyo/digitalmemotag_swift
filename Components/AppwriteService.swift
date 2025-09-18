import Appwrite

class AppwriteService {
    static let shared = AppwriteService()
    
    let client = Client()
    let databases: Databases
    
    // Your actual project details
    let databaseId = "68cba284000aabe9c076"
    let itemsCollectionId = "items"
    let messagesCollectionId = "messages"
    
    private init() {
        client
            .setEndpoint("https://sfo.cloud.appwrite.io/v1")
        
        _ = client.setProject("68cba284000aabe9c076")
        
        databases = Databases(client)
    }
    
    // MARK: - Items Functions
    func createItem(itemId: String, name: String, location: String, status: String = "Working") async throws {
        let data: [String: Any] = [
            "item_id": itemId,
            "name": name,
            "location": location,
            "status": status
        ]
        
        _ = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: itemsCollectionId,
            documentId: ID.unique(),
            data: data
        )
    }
    
    // MARK: - Messages Functions
    func getMessages(for itemId: String) async throws -> Any {
        // Simplified return type
        let response = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: messagesCollectionId,
            queries: [
                Query.equal("item_id", value: itemId),
                Query.orderDesc("$createdAt")
            ]
        )
        return response.documents
    }
    
    func postMessage(itemId: String, message: String, userName: String = "匿名", msgType: String = "general") async throws {
        let data: [String: Any] = [
            "item_id": itemId,
            "message": message,
            "user_name": userName,
            "msg_type": msgType
        ]
        
        _ = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: messagesCollectionId,
            documentId: ID.unique(),
            data: data
        )
    }
}
