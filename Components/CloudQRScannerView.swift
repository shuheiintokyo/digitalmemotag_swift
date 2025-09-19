//
//  CloudQRScannerView.swift
//  digitalmemotag
//
//  QR Scanner with proper camera permissions and cloud data manager integration
//

import SwiftUI
import CoreData
import AVFoundation

struct CloudQRScannerView: View {
    @StateObject private var dataManager = CloudDataManager.shared
    @State private var isPresentingScanner = false
    @State private var showingManualEntry = false
    @State private var manualItemId = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingItemDetail = false
    @State private var foundItem: CloudItem?
    @State private var isSearching = false
    @State private var showingCameraPermissionAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Connection Status Header
                ConnectionStatusHeader(dataManager: dataManager)
                
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("QRコードスキャン")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("製品のQRコードをスキャンしてアクセス")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Searching Status
                if isSearching {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("製品を検索中...")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        checkCameraPermissionAndScan()
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("QRコードをスキャン")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSearching ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isSearching)
                    
                    Button(action: {
                        showingManualEntry = true
                    }) {
                        HStack {
                            Image(systemName: "keyboard")
                            Text("手動で製品IDを入力")
                        }
                        .font(.headline)
                        .foregroundColor(isSearching ? .gray : .blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((isSearching ? Color.gray : Color.blue).opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isSearching)
                    
                    Button(action: {
                        Task {
                            await dataManager.refreshData()
                        }
                    }) {
                        HStack {
                            Image(systemName: dataManager.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                            Text("データを更新")
                        }
                        .font(.headline)
                        .foregroundColor(dataManager.isLoading ? .gray : .orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((dataManager.isLoading ? Color.gray : Color.orange).opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(dataManager.isLoading)
                }
                .padding(.horizontal, 40)
                
                // Recent Items (if any)
                if dataManager.hasItems {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近の製品")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(dataManager.items.prefix(5))) { item in
                                    RecentItemCard(item: item) {
                                        foundItem = item
                                        showingItemDetail = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("QRスキャン")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $isPresentingScanner) {
            QRCodeScannerView { result in
                isPresentingScanner = false
                handleScannedCode(result)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView(itemId: $manualItemId) { itemId in
                showingManualEntry = false
                if !itemId.isEmpty {
                    handleScannedCode(itemId)
                }
            }
        }
        .sheet(isPresented: $showingItemDetail) {
            if let item = foundItem {
                NavigationView {
                    CloudItemDetailView(item: item, dataManager: dataManager)
                        .navigationBarItems(trailing: Button("閉じる") {
                            showingItemDetail = false
                            foundItem = nil
                        })
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("スキャン結果"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingCameraPermissionAlert) {
            Alert(
                title: Text("カメラへのアクセスが必要です"),
                message: Text("QRコードをスキャンするためにカメラへのアクセスを許可してください。"),
                primaryButton: .default(Text("設定を開く")) {
                    openAppSettings()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .onAppear {
            // Data is already loaded via singleton, no need to load again
        }
    }
    
    // MARK: - Camera Permission Handling
    
    private func checkCameraPermissionAndScan() {
        CameraPermissionManager.checkCameraPermission { [self] granted in
            DispatchQueue.main.async {
                if granted {
                    self.isPresentingScanner = true
                } else {
                    self.showingCameraPermissionAlert = true
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // MARK: - QR Code Handling
    
    private func handleScannedCode(_ code: String) {
        print("📱 Scanned code: \(code)")
        
        let itemId = extractItemId(from: code)
        print("🔍 Extracted item ID: \(itemId)")
        
        Task {
            await searchForItem(itemId: itemId)
        }
    }
    
    private func extractItemId(from code: String) -> String {
        print("🔍 Processing code: \(code)")
        
        // Try URL parsing first
        if let url = URL(string: code),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            
            // Check for item_id parameter (NEW FORMAT)
            if let itemParam = components.queryItems?.first(where: { $0.name == "item_id" })?.value {
                print("✅ Found item_id parameter: \(itemParam)")
                return itemParam
            }
            
            // Check for item parameter (LEGACY)
            if let itemParam = components.queryItems?.first(where: { $0.name == "item" })?.value {
                print("✅ Found item parameter: \(itemParam)")
                return itemParam
            }
            
            // Check legacy format: digitalmemotag://product/ITEM_ID
            if url.scheme == "digitalmemotag" && url.host == "product" {
                let itemId = url.path.replacingOccurrences(of: "/", with: "")
                if !itemId.isEmpty {
                    print("✅ Found legacy format item ID: \(itemId)")
                    return itemId
                }
            }
            
            // Check new format: digitalmemotag://item?item_id=ITEM_ID
            if url.scheme == "digitalmemotag" && url.host == "item" {
                if let itemParam = components.queryItems?.first(where: { $0.name == "item_id" })?.value {
                    print("✅ Found new format item ID: \(itemParam)")
                    return itemParam
                }
            }
        }
        
        // If not a URL, assume it's the item ID directly
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ Using code as item ID: \(trimmedCode)")
        return trimmedCode
    }
    
    private func searchForItem(itemId: String) async {
        await MainActor.run {
            isSearching = true
        }
        
        // First check if item is already loaded locally
        if let localItem = dataManager.findItem(byId: itemId) {
            await MainActor.run {
                foundItem = localItem
                showingItemDetail = true
                alertMessage = "製品「\(localItem.name)」が見つかりました（ローカル）"
                isSearching = false
                print("✅ Found item locally: \(localItem.name)")
            }
            return
        }
        
        // If not found locally, search in cloud
        print("🌐 Item not found locally, searching in cloud...")
        
        do {
            // Try to get item from cloud
            if let cloudItemData = try await AppwriteService.shared.getItem(itemId: itemId) {
                // Convert to CloudItem
                if let cloudItem = CloudItem.from(appwriteData: cloudItemData) {
                    // Load messages for this item
                    let messagesData = try await AppwriteService.shared.getMessages(for: itemId)
                    let messages = messagesData.compactMap { data in
                        CloudMessage.from(appwriteData: data)
                    }.sorted { $0.createdAt > $1.createdAt }
                    
                    // Create complete CloudItem with messages
                    var completeItem = cloudItem
                    completeItem.messages = messages
                    
                    await MainActor.run {
                        // Add to local items array in data manager
                        dataManager.items.insert(completeItem, at: 0)
                        
                        foundItem = completeItem
                        showingItemDetail = true
                        alertMessage = "製品「\(completeItem.name)」が見つかりました（クラウドから同期）"
                        isSearching = false
                        print("✅ Found and synced item from cloud: \(completeItem.name)")
                    }
                } else {
                    await MainActor.run {
                        alertMessage = "製品データの解析に失敗しました"
                        showingAlert = true
                        isSearching = false
                    }
                }
            } else {
                // Item not found in cloud
                await MainActor.run {
                    alertMessage = "製品ID「\(itemId)」が見つかりません。\n\nクラウドとローカルの両方で検索しましたが、該当する製品が存在しませんでした。"
                    showingAlert = true
                    isSearching = false
                    print("❌ Item not found: \(itemId)")
                }
            }
        } catch {
            await MainActor.run {
                alertMessage = "検索中にエラーが発生しました: \(error.localizedDescription)"
                showingAlert = true
                isSearching = false
                print("❌ Search error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct ConnectionStatusHeader: View {
    @ObservedObject var dataManager: CloudDataManager
    
    var body: some View {
        HStack {
            Circle()
                .fill(dataManager.syncStatus.color)
                .frame(width: 8, height: 8)
            
            Text(dataManager.syncStatus.displayText)
                .font(.caption)
                .foregroundColor(dataManager.syncStatus.color)
            
            Spacer()
            
            if dataManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
    }
}

struct RecentItemCard: View {
    let item: CloudItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 8, height: 8)
                    
                    Text(item.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                HStack {
                    Text(item.itemId)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: 120)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
