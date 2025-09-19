//
//  ContentView.swift
//  digitalmemotag
//
//  Main app navigation with cloud-first architecture
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CloudDashboardView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    Text("製品一覧")
                }
                .tag(0)
            
            CloudQRScannerView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "qrcode.viewfinder" : "qrcode.viewfinder")
                    Text("QRスキャン")
                }
                .tag(1)
            
            CloudSettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "gear.circle.fill" : "gear.circle")
                    Text("設定")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .onAppear {
            // Configure tab bar appearance
            configureTabBarAppearance()
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Configure normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]
        
        // Configure selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Cloud Settings View

struct CloudSettingsView: View {
    @StateObject private var dataManager = CloudDataManager(context: PersistenceController.shared.container.viewContext)
    @AppStorage("quickActionBlue") private var quickActionBlue = "作業を開始しました"
    @AppStorage("quickActionGreen") private var quickActionGreen = "作業を完了しました"
    @AppStorage("quickActionYellow") private var quickActionYellow = "作業に遅れが生じています"
    @AppStorage("quickActionRed") private var quickActionRed = "問題が発生しました。"
    
    @State private var showingResetAlert = false
    @State private var showingAbout = false
    @State private var showingCloudDebug = false
    @State private var showingSyncAlert = false
    @State private var syncAlertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Cloud Status Section
                Section(header: Text("クラウド状態")) {
                    HStack {
                        Circle()
                            .fill(dataManager.syncStatus.color)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("同期状態")
                                .font(.headline)
                            Text(dataManager.syncStatus.displayText)
                                .font(.caption)
                                .foregroundColor(dataManager.syncStatus.color)
                        }
                        
                        Spacer()
                        
                        if dataManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    HStack {
                        Text("アイテム数")
                        Spacer()
                        Text("\(dataManager.items.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = dataManager.lastError {
                        Text("エラー: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
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
                    Button("今すぐ同期") {
                        Task {
                            await performManualSync()
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(dataManager.isLoading)
                    
                    Button("設定をリセット") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                // Debug Section
                Section(header: Text("デバッグ")) {
                    Button("クラウド接続テスト") {
                        showingCloudDebug = true
                    }
                    .foregroundColor(.orange)
                    
                    Button("Appwrite詳細情報") {
                        showCloudInfo()
                    }
                    .foregroundColor(.purple)
                }
                
                // App Information
                Section(header: Text("アプリ情報")) {
                    InfoRow(label: "アプリ名", value: "Digital Memo Tag")
                    InfoRow(label: "バージョン", value: "1.0.0 (Cloud)")
                    InfoRow(label: "ビルド", value: "2025.09.19")
                    InfoRow(label: "アーキテクチャ", value: "Cloud-First")
                    InfoRow(label: "開発者", value: "DigitalMemoTag Team")
                    
                    Button("アプリについて") {
                        showingAbout = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("設定")
            .refreshable {
                await dataManager.refreshData()
            }
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
        .alert(isPresented: $showingSyncAlert) {
            Alert(
                title: Text("同期結果"),
                message: Text(syncAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingAbout) {
            CloudAboutView()
        }
        .sheet(isPresented: $showingCloudDebug) {
            CloudDebugView()
        }
    }
    
    private func performManualSync() async {
        await dataManager.refreshData()
        
        await MainActor.run {
            if dataManager.isOnline {
                syncAlertMessage = "同期が完了しました。\n\nアイテム数: \(dataManager.items.count)"
            } else {
                syncAlertMessage = "オフラインのため同期できませんでした。"
            }
            showingSyncAlert = true
        }
    }
    
    private func showCloudInfo() {
        let appwriteService = AppwriteService.shared
        syncAlertMessage = """
        Appwrite接続情報:
        
        エンドポイント: sfo.cloud.appwrite.io
        プロジェクトID: 68cba284000aabe9c076
        データベースID: \(appwriteService.databaseId)
        
        コレクション:
        • Items: \(appwriteService.itemsCollectionId)
        • Messages: \(appwriteService.messagesCollectionId)
        
        接続状態: \(dataManager.isOnline ? "オンライン" : "オフライン")
        """
        showingSyncAlert = true
    }
    
    private func resetSettings() {
        quickActionBlue = "作業を開始しました"
        quickActionGreen = "作業を完了しました"
        quickActionYellow = "作業に遅れが生じています"
        quickActionRed = "問題が発生しました。"
        
        syncAlertMessage = "設定をデフォルト値にリセットしました。"
        showingSyncAlert = true
    }
}

// MARK: - Supporting Views

struct QuickActionSetting: View {
    let title: String
    let color: Color
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            TextField("\(title)のメッセージ", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.vertical, 4)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct CloudAboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App Title
                    VStack(spacing: 20) {
                        Text("Digital Memo Tag")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Version 1.0.0 (Cloud)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Cloud Architecture Badge
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.blue)
                        Text("クラウドファースト アーキテクチャ")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Description
                    VStack(spacing: 16) {
                        Text("リアルタイム製品管理と\nチーム連携を実現")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        
                        Text("クラウドファーストアーキテクチャにより、複数のデバイス間でのリアルタイムデータ同期と、チームメンバー間でのシームレスな連携を可能にします。")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Features
                    VStack(spacing: 20) {
                        Text("主な機能")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            CloudFeatureCard(
                                icon: "qrcode.viewfinder",
                                title: "QRスキャン",
                                description: "瞬時に製品にアクセス"
                            )
                            
                            CloudFeatureCard(
                                icon: "cloud.fill",
                                title: "クラウド同期",
                                description: "リアルタイム連携"
                            )
                            
                            CloudFeatureCard(
                                icon: "message.circle",
                                title: "メッセージング",
                                description: "チーム間の連絡"
                            )
                            
                            CloudFeatureCard(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "ステータス管理",
                                description: "進捗の可視化"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Cloud Benefits
                    VStack(spacing: 16) {
                        Text("クラウドファーストの利点")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            CloudBenefitRow(
                                icon: "arrow.clockwise",
                                title: "自動同期",
                                description: "30秒ごとに最新データを取得"
                            )
                            
                            CloudBenefitRow(
                                icon: "person.3.fill",
                                title: "マルチユーザー",
                                description: "複数人での同時作業が可能"
                            )
                            
                            CloudBenefitRow(
                                icon: "iphone.and.ipad",
                                title: "クロスデバイス",
                                description: "どのデバイスからでもアクセス"
                            )
                            
                            CloudBenefitRow(
                                icon: "shield.fill",
                                title: "データ保護",
                                description: "クラウドバックアップで安全"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Contact Information
                    VStack(spacing: 12) {
                        Text("開発・サポート")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            Text("DigitalMemoTag Team")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("support@digitalmemotag.com")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text("© 2025 DigitalMemoTag. All rights reserved.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("アプリについて")
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct CloudFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(12)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CloudBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CloudDebugView: View {
    @StateObject private var appwriteService = AppwriteService.shared
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("接続テスト")) {
                    Button("基本接続テスト") {
                        Task {
                            await runBasicTest()
                        }
                    }
                    .disabled(isRunningTests)
                    
                    Button("完全テストスイート") {
                        Task {
                            await runFullTests()
                        }
                    }
                    .disabled(isRunningTests)
                }
                
                Section(header: Text("テスト結果")) {
                    if testResults.isEmpty {
                        Text("テストを実行してください")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                            Text(result)
                                .font(.caption)
                                .foregroundColor(
                                    result.hasPrefix("✅") ? .green :
                                    result.hasPrefix("❌") ? .red : .primary
                                )
                        }
                    }
                }
            }
            .navigationTitle("クラウドデバッグ")
            .navigationBarItems(
                leading: Button("クリア") {
                    testResults.removeAll()
                },
                trailing: Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func runBasicTest() async {
        isRunningTests = true
        await appwriteService.testConnection()
        
        await MainActor.run {
            let status = appwriteService.isConnected ? "✅ 接続成功" : "❌ 接続失敗"
            testResults.append("\(Date().formatForDisplay()): \(status)")
            isRunningTests = false
        }
    }
    
    private func runFullTests() async {
        isRunningTests = true
        testResults.append("=== 完全テスト開始 ===")
        
        // Add comprehensive testing here
        await runBasicTest()
        
        await MainActor.run {
            testResults.append("=== テスト完了 ===")
            isRunningTests = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif
