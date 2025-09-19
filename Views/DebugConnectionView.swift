// MARK: - DebugConnectionView.swift (Create this as a separate file)
import SwiftUI
import Appwrite

struct DebugConnectionView: View {
    @StateObject private var appwriteService = AppwriteService.shared
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("接続状態")) {
                    HStack {
                        Circle()
                            .fill(appwriteService.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading) {
                            Text("Appwrite接続")
                                .font(.headline)
                            Text(appwriteService.isConnected ? "接続済み" : "未接続")
                                .font(.caption)
                                .foregroundColor(appwriteService.isConnected ? .green : .red)
                        }
                        
                        Spacer()
                        
                        Button("テスト") {
                            Task {
                                await runConnectionTest()
                            }
                        }
                        .disabled(isRunningTests)
                    }
                    
                    if let error = appwriteService.lastError {
                        Text("エラー: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("設定情報")) {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Endpoint", value: "https://sfo.cloud.appwrite.io/v1")
                        InfoRow(label: "Project ID", value: "68cba284000aabe9c076")
                        InfoRow(label: "Database ID", value: appwriteService.databaseId)
                        InfoRow(label: "Items Collection", value: appwriteService.itemsCollectionId)
                        InfoRow(label: "Messages Collection", value: appwriteService.messagesCollectionId)
                    }
                }
                
                Section(header: Text("テスト結果")) {
                    if testResults.isEmpty {
                        Text("テストを実行してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.hasPrefix("✅") ? .green : result.hasPrefix("❌") ? .red : .primary)
                        }
                    }
                }
                
                Section(header: Text("アクション")) {
                    Button("完全なテストを実行") {
                        Task {
                            await runFullTests()
                        }
                    }
                    .disabled(isRunningTests)
                    
                    Button("テスト結果をクリア") {
                        testResults.removeAll()
                    }
                    
                    Button("再接続を試行") {
                        Task {
                            await appwriteService.testConnection()
                        }
                    }
                    .disabled(isRunningTests)
                }
            }
            .navigationTitle("接続デバッグ")
            .refreshable {
                await runConnectionTest()
            }
        }
    }
    
    private func runConnectionTest() async {
        await appwriteService.testConnection()
        
        let status = appwriteService.isConnected ? "✅ 接続成功" : "❌ 接続失敗"
        await MainActor.run {
            testResults.append("\(Date().formatForDisplay()): \(status)")
        }
    }
    
    private func runFullTests() async {
        await MainActor.run {
            isRunningTests = true
            testResults.append("--- テスト開始 ---")
        }
        
        // Test 1: Basic connection
        await MainActor.run {
            testResults.append("テスト1: 基本接続")
        }
        await runConnectionTest()
        
        // Test 2: Database access
        await MainActor.run {
            testResults.append("テスト2: データベースアクセス")
        }
        
        let databaseAccessResult = await appwriteService.testDatabaseAccess()
        await MainActor.run {
            if databaseAccessResult {
                testResults.append("✅ データベースアクセス成功")
            } else {
                testResults.append("❌ データベースアクセス失敗")
            }
        }
        
        // Test 3: Collections access
        await MainActor.run {
            testResults.append("テスト3: コレクションアクセス")
        }
        
        let itemsCollectionResult = await appwriteService.testCollectionAccess(collectionId: appwriteService.itemsCollectionId)
        await MainActor.run {
            if itemsCollectionResult {
                testResults.append("✅ Itemsコレクションアクセス成功")
            } else {
                testResults.append("❌ Itemsコレクションアクセス失敗")
            }
        }
        
        let messagesCollectionResult = await appwriteService.testCollectionAccess(collectionId: appwriteService.messagesCollectionId)
        await MainActor.run {
            if messagesCollectionResult {
                testResults.append("✅ Messagesコレクションアクセス成功")
            } else {
                testResults.append("❌ Messagesコレクションアクセス失敗")
            }
        }
        
        // Test 4: Sample item creation (if connection works)
        if appwriteService.isConnected {
            await MainActor.run {
                testResults.append("テスト4: サンプルアイテム作成")
            }
            
            let testItemId = "TEST-\(Int(Date().timeIntervalSince1970))"
            
            do {
                _ = try await appwriteService.createItem(
                    itemId: testItemId,
                    name: "テストアイテム",
                    location: "テスト場所",
                    status: "Working"
                )
                await MainActor.run {
                    testResults.append("✅ サンプルアイテム作成成功: \(testItemId)")
                }
            } catch {
                await MainActor.run {
                    testResults.append("❌ サンプルアイテム作成失敗: \(error.localizedDescription)")
                }
            }
        }
        
        await MainActor.run {
            testResults.append("--- テスト完了 ---")
            isRunningTests = false
        }
    }
}
