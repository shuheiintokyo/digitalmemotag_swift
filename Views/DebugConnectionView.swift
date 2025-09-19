// MARK: - DebugConnectionView.swift (Add this to your Settings)
import SwiftUI

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
        
        do {
            _ = try await appwriteService.databases.get(databaseId: appwriteService.databaseId)
            await MainActor.run {
                testResults.append("✅ データベースアクセス成功")
            }
        } catch {
            await MainActor.run {
                testResults.append("❌ データベースアクセス失敗: \(error.localizedDescription)")
            }
        }
        
        // Test 3: Collections access
        await MainActor.run {
            testResults.append("テスト3: コレクションアクセス")
        }
        
        do {
            _ = try await appwriteService.databases.listDocuments(
                databaseId: appwriteService.databaseId,
                collectionId: appwriteService.itemsCollectionId,
                queries: [Query.limit(1)]
            )
            await MainActor.run {
                testResults.append("✅ Itemsコレクションアクセス成功")
            }
        } catch {
            await MainActor.run {
                testResults.append("❌ Itemsコレクションアクセス失敗: \(error.localizedDescription)")
            }
        }
        
        do {
            _ = try await appwriteService.databases.listDocuments(
                databaseId: appwriteService.databaseId,
                collectionId: appwriteService.messagesCollectionId,
                queries: [Query.limit(1)]
            )
            await MainActor.run {
                testResults.append("✅ Messagesコレクションアクセス成功")
            }
        } catch {
            await MainActor.run {
                testResults.append("❌ Messagesコレクションアクセス失敗: \(error.localizedDescription)")
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

// Update your SettingsView to include the debug option
struct UpdatedSettingsView: View {
    @AppStorage("quickActionBlue") private var quickActionBlue = "作業を開始しました"
    @AppStorage("quickActionGreen") private var quickActionGreen = "作業を完了しました"
    @AppStorage("quickActionYellow") private var quickActionYellow = "作業に遅れが生じています"
    @AppStorage("quickActionRed") private var quickActionRed = "問題が発生しました。"
    
    @State private var showingResetAlert = false
    @State private var showingAbout = false
    @State private var showingDebug = false
    
    var body: some View {
        NavigationView {
            List {
                // Quick Action Settings
                Section(header: Text("クイックアクションボタン設定")) {
                    QuickActionSetting(
                        title: "青ボタン",
                        color: .blue,
                        text: $quickActionBlue
                    )
                    
                    QuickActionSetting(
                        title: "緑ボタン",
                        color: .green,
                        text: $quickActionGreen
                    )
                    
                    QuickActionSetting(
                        title: "黄ボタン",
                        color: .orange,
                        text: $quickActionYellow
                    )
                    
                    QuickActionSetting(
                        title: "赤ボタン",
                        color: .red,
                        text: $quickActionRed
                    )
                }
                
                // Data Management
                Section(header: Text("データ管理")) {
                    Button("Appwriteから同期") {
                        Task {
                            let itemManager = ItemManager(context: PersistenceController.shared.container.viewContext)
                            await itemManager.syncFromAppwrite()
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button("設定をリセット") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                // Debug Section
                Section(header: Text("デバッグ")) {
                    Button("接続デバッグ") {
                        showingDebug = true
                    }
                    .foregroundColor(.orange)
                }
                
                // App Information
                Section(header: Text("アプリ情報")) {
                    InfoRow(label: "アプリ名", value: "Digital Memo Tag")
                    InfoRow(label: "バージョン", value: "1.0.0")
                    InfoRow(label: "ビルド", value: "2025.09.18")
                    InfoRow(label: "開発者", value: "DigitalMemoTag Team")
                    
                    Button("アプリについて") {
                        showingAbout = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("設定")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("設定をリセット"),
                message: Text("すべての設定をデフォルト値に戻しますか？"),
                primaryButton: .destructive(Text("リセット")) {
                    resetSettings()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingDebug) {
            DebugConnectionView()
        }
    }
    
    private func resetSettings() {
        quickActionBlue = "作業を開始しました"
        quickActionGreen = "作業を完了しました"
        quickActionYellow = "作業に遅れが生じています"
        quickActionRed = "問題が発生しました。"
    }
}
