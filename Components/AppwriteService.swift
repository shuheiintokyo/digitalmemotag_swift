//
//  AppwriteService.swift
//  digitalmemotag
//
//  Enhanced Appwrite service with authentication integration
//

import Appwrite
import Foundation

class AppwriteService: ObservableObject {
    static let shared = AppwriteService()
    
    private var client: Client
    let databases: Databases
    
    // PRODUCTION: Use the correct database ID from your Appwrite dashboard
    let databaseId = "68cbba0e00372afe7c23"  // Fixed: with double 'b'
    let itemsCollectionId = "Items"  // Capital 'I'
    let messagesCollectionId = "messages"  // lowercase 'm'
    
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        var displayText: String {
            switch self {
            case .disconnected: return "未接続"
            case .connecting: return "接続中..."
            case .connected: return "接続済み"
            case .error(let message): return "エラー: \(message)"
            }
        }
    }
    
    private init() {
        self.client = Client()
            .setEndpoint("https://sfo.cloud.appwrite.io/v1")
            .setProject("68cba284000aabe9c076")
        
        self.databases = Databases(client)
        
        // Test connection on initialization
        Task {
            await testConnection()
        }
    }
    
    // MARK: - Client Management
    
    func updateClient(_ newClient: Client) {
        self.client = newClient
        // Re-initialize databases with new client
        let newDatabases = Databases(newClient)
        // We can't reassign the let property, so we'll work with the client directly
        
        // Test connection with updated client
        Task {
            await testConnection()
        }
    }
    
    func getCurrentClient() -> Client {
        return client
    }
    
    // MARK: - Connection Testing
    
    @MainActor
    func testConnection() async {
        connectionStatus = .connecting
        
        do {
            let databases = Databases(client)
            _ = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                queries: [Query.limit(1)]
            )
            
            isConnected = true
            lastError = nil
            connectionStatus = .connected
            print("✅ Successfully connected to Appwrite database")
            
        } catch {
            isConnected = false
            let errorMessage = parseAppwriteError(error)
            lastError = errorMessage
            connectionStatus = .error(errorMessage)
            print("❌ Failed to connect to Appwrite: \(error)")
        }
    }
    
    // MARK: - Items Functions
    
    func createItem(itemId: String, name: String, location: String, status: String = "Working") async throws -> String {
        guard isConnected else {
            throw AppwriteError.notConnected
        }
        
        let data: [String: Any] = [
            "item_id": itemId,
            "name": name,
            "location": location,
            "status": status
        ]
        
        print("📝 Creating item with data: \(data)")
        
        do {
            let databases = Databases(client)
            let document = try await databases.createDocument(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                documentId: ID.unique(),
                data: data
            )
            
            print("✅ Created item in Appwrite with document ID: \(document.id)")
            return document.id
            
        } catch {
            let errorMessage = parseAppwriteError(error)
            print("❌ Failed to create item: \(errorMessage)")
            throw AppwriteError.operationFailed(errorMessage)
        }
    }
    
    func getItem(itemId: String) async throws -> [String: Any]? {
        guard isConnected else {
            throw AppwriteError.notConnected
        }
        
        do {
            let databases = Databases(client)
            let response = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                queries: [
                    Query.equal("item_id", value: itemId),
                    Query.limit(1)
                ]
            )
            
            return response.documents.first?.data
            
        } catch {
            let errorMessage = parseAppwriteError(error)
            print("❌ Failed to get item \(itemId): \(errorMessage)")
            throw AppwriteError.operationFailed(errorMessage)
        }
    }
    
    func getAllItems() async throws -> [[String: Any]] {
        guard isConnected else {
            throw AppwriteError.notConnected
        }
        
        print("🔍 Fetching items from collection: '\(itemsCollectionId)' in database: '\(databaseId)'")
        
        do {
            let databases = Databases(client)
            let response = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                queries: [
                    Query.orderDesc("$createdAt"),
                    Query.limit(100)
                ]
            )
            
            print("📊 Got \(response.documents.count) documents from Appwrite")
            
            // Log the first document to see its structure
            if let firstDoc = response.documents.first {
                print("📄 First document structure:")
                for (key, value) in firstDoc.data {
                    print("   \(key): \(value)")
                }
            }
            
            return response.documents.map { $0.data }
            
        } catch {
            let errorMessage = parseAppwriteError(error)
            print("❌ getAllItems error: \(error)")
            throw AppwriteError.operationFailed(errorMessage)
        }
    }
    
    func updateItemStatus(itemId: String, status: String) async throws {
        guard isConnected else {
            throw AppwriteError.notConnected
        }
        
        do {
            let databases = Databases(client)
            // First, find the document ID
            let items = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                queries: [Query.equal("item_id", value: itemId)]
            )
            
            guard let document = items.documents.first else {
                throw AppwriteError.itemNotFound
            }
            
            _ = try await databases.updateDocument(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                documentId: document.id,
                data: ["status": status]
            )
            
            print("✅ Updated item status in Appwrite: \(itemId) -> \(status)")
            
        } catch {
            let errorMessage = parseAppwriteError(error)
            print("❌ Failed to update item status: \(errorMessage)")
            throw AppwriteError.operationFailed(errorMessage)
        }
    }
    
    func deleteItem(itemId: String) async throws {
        guard isConnected else {
            throw AppwriteError.notConnected
        }
        
        do {
            let databases = Databases(client)
            // First, find the document ID
            let items = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                queries: [Query.equal("item_id", value: itemId)]
            )
            
            guard let document = items.documents.first else {
                throw AppwriteError.itemNotFound
            }
            
            // Delete all messages first
            let messages = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: messagesCollectionId,
                queries: [Query.equal("item_id", value: itemId)]
            )
            
            for message in messages.documents {
                try await databases.deleteDocument(
                    databaseId: databaseId,
                    collectionId: messagesCollectionId,
                    documentId: message.id
                )
            }
            
            // Then delete the item
            try await databases.deleteDocument(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                documentId: document.id
            )
            
            print("✅ Deleted item from Appwrite: \(itemId)")
            
        } catch {
            let errorMessage = parseAppwriteError(error)
            print("❌ Failed to delete item: \(errorMessage)")
            throw AppwriteError.operationFailed(errorMessage)
        }
    }
    
    // MARK: - Messages Functions
    
    func getMessages(for itemId: String) async throws -> [[String: Any]] {
        guard isConnected else {
            throw AppwriteError.notConnected
        }
        
        do {
            let databases = Databases(client)
            let response = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: messagesCollectionId,
                queries: [
                    Query.equal("item_id", value: itemId),
                    Query.orderDesc("$createdAt"),
                    Query.limit(50)
                ]
            )
            
            return response.documents.map { $0.data }
            
        } catch {
            let errorMessage = parseAppwriteError(error)
            print("❌ Failed to get messages for item \(itemId): \(errorMessage)")
            throw AppwriteError.operationFailed(errorMessage)
        }
    }
    
    func postMessage(itemId: String, message: String, userName: String = "匿名", msgType: String = "general") async throws -> String {
        guard isConnected else {
            throw AppwriteError.notConnected
        }
        
        let data: [String: Any] = [
            "item_id": itemId,
            "message": message,
            "user_name": userName,
            "msg_type": msgType
        ]
        
        do {
            let databases = Databases(client)
            let document = try await databases.createDocument(
                databaseId: databaseId,
                collectionId: messagesCollectionId,
                documentId: ID.unique(),
                data: data
            )
            
            print("✅ Posted message to Appwrite for item: \(itemId)")
            return document.id
            
        } catch {
            let errorMessage = parseAppwriteError(error)
            print("❌ Failed to post message: \(errorMessage)")
            throw AppwriteError.operationFailed(errorMessage)
        }
    }
    
    func deleteMessage(documentId: String) async throws {
        guard isConnected else {
            throw AppwriteError.notConnected
        }
        
        do {
            let databases = Databases(client)
            try await databases.deleteDocument(
                databaseId: databaseId,
                collectionId: messagesCollectionId,
                documentId: documentId
            )
            
            print("✅ Deleted message from Appwrite: \(documentId)")
            
        } catch {
            let errorMessage = parseAppwriteError(error)
            print("❌ Failed to delete message: \(errorMessage)")
            throw AppwriteError.operationFailed(errorMessage)
        }
    }
    
    // MARK: - Sync Functions
    
    func syncItemToAppwrite(item: Item) async throws {
        guard let itemId = item.itemId,
              let name = item.name else {
            throw AppwriteError.invalidData("Invalid item data")
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
    
    // MARK: - Testing Functions
    
    func testDatabaseAccess() async -> Bool {
        do {
            let databases = Databases(client)
            _ = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: itemsCollectionId,
                queries: [Query.limit(1)]
            )
            return true
        } catch {
            print("❌ Database access test failed: \(parseAppwriteError(error))")
            return false
        }
    }
    
    func testCollectionAccess(collectionId: String) async -> Bool {
        do {
            let databases = Databases(client)
            _ = try await databases.listDocuments(
                databaseId: databaseId,
                collectionId: collectionId,
                queries: [Query.limit(1)]
            )
            return true
        } catch {
            print("❌ Collection access test failed for \(collectionId): \(parseAppwriteError(error))")
            return false
        }
    }
    
    // MARK: - Error Handling
    
    private func parseAppwriteError(_ error: Error) -> String {
        if let appwriteError = error as? AppwriteError {
            return appwriteError.localizedDescription
        }
        
        let errorString = error.localizedDescription
        
        // Parse common Appwrite errors
        if errorString.contains("401") {
            return "認証エラー: APIキーまたはプロジェクトIDが正しくありません"
        } else if errorString.contains("404") {
            return "リソースが見つかりません: データベースまたはコレクションが存在しません"
        } else if errorString.contains("500") {
            return "サーバーエラー: Appwriteサーバーに問題があります"
        } else if errorString.contains("network") || errorString.contains("internet") {
            return "ネットワークエラー: インターネット接続を確認してください"
        } else {
            return "不明なエラー: \(errorString)"
        }
    }
}

// MARK: - Custom Error Types

enum AppwriteError: Error, LocalizedError {
    case notConnected
    case itemNotFound
    case invalidData(String)
    case operationFailed(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Appwriteサーバーに接続されていません"
        case .itemNotFound:
            return "指定されたアイテムが見つかりません"
        case .invalidData(let message):
            return "無効なデータ: \(message)"
        case .operationFailed(let message):
            return "操作に失敗しました: \(message)"
        case .configurationError(let message):
            return "設定エラー: \(message)"
        }
    }
}

// MARK: - Health Check Extension

extension AppwriteService {
    func performHealthCheck() async -> HealthCheckResult {
        var results: [String] = []
        
        // Test basic connection
        let connectionResult = await testDatabaseAccess()
        results.append(connectionResult ? "✅ データベース接続: 成功" : "❌ データベース接続: 失敗")
        
        // Test collections
        let itemsResult = await testCollectionAccess(collectionId: itemsCollectionId)
        results.append(itemsResult ? "✅ Itemsコレクション: 成功" : "❌ Itemsコレクション: 失敗")
        
        let messagesResult = await testCollectionAccess(collectionId: messagesCollectionId)
        results.append(messagesResult ? "✅ Messagesコレクション: 成功" : "❌ Messagesコレクション: 失敗")
        
        let overallSuccess = connectionResult && itemsResult && messagesResult
        
        return HealthCheckResult(
            isHealthy: overallSuccess,
            details: results,
            timestamp: Date()
        )
    }
}

struct HealthCheckResult {
    let isHealthy: Bool
    let details: [String]
    let timestamp: Date
    
    var summary: String {
        return isHealthy ? "すべてのテストが成功しました" : "一部のテストが失敗しました"
    }
}
