//
//  ItemDetailView.swift
//  digitalmemotag
//
//  Created by Shuhei Kinugasa on 2025/09/15.
//

// MARK: - ItemDetailView.swift (Message Board)
import SwiftUI
import CoreData
import UIKit
import AVFoundation

// MARK: - CloudItemDetailView.swift
struct CloudItemDetailView: View {
    let item: CloudItem
    let dataManager: CloudDataManager
    
    @State private var newMessage = ""
    @State private var userName = ""
    @State private var showingQRCode = false
    @State private var isAddingMessage = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Item Info Header
            CloudItemInfoHeader(item: item, showingQRCode: $showingQRCode)
            
            // Quick Action Buttons
            CloudQuickActionButtons(
                item: item,
                dataManager: dataManager,
                isLoading: isAddingMessage
            )
            
            // Message Input
            CloudMessageInputView(
                newMessage: $newMessage,
                userName: $userName,
                isLoading: isAddingMessage,
                onSend: {
                    await sendMessage()
                }
            )
            
            // Messages List
            CloudMessagesList(
                messages: item.messages,
                isLoading: dataManager.isLoading
            )
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            trailing: HStack {
                Button(action: { showingQRCode = true }) {
                    Image(systemName: "qrcode")
                }
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        )
        .sheet(isPresented: $showingQRCode) {
            CloudQRCodeDisplayView(item: item)
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("製品を削除"),
                message: Text("この製品を削除してもよろしいですか？"),
                primaryButton: .destructive(Text("削除")) {
                    Task {
                        if await dataManager.deleteItem(item) {
                            // Navigate back
                        }
                    }
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .onAppear {
            Task {
                await dataManager.loadMessages(for: item)
            }
        }
    }
    
    private func sendMessage() async {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isAddingMessage = true
        
        let trimmedMessage = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let success = await dataManager.addMessage(
            to: item,
            message: trimmedMessage,
            userName: trimmedUserName.isEmpty ? "匿名" : trimmedUserName,
            type: .general
        )
        
        if success {
            newMessage = ""
        }
        
        isAddingMessage = false
    }
}

// MARK: - ItemInfoHeader.swift
struct ItemInfoHeader: View {
    let item: Item
    @Binding var showingQRCode: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? "Unknown")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("ID: \(item.itemId ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let location = item.location, !location.isEmpty {
                        Text("場所: \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(item.statusEnum.color)
                            .frame(width: 8, height: 8)
                        Text(item.statusEnum.localizedString)
                            .font(.caption)
                            .foregroundColor(item.statusEnum.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.statusEnum.color.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button(action: { showingQRCode = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "qrcode")
                            Text("QR表示")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - QuickActionButtons.swift
struct QuickActionButtons: View {
    let onAction: (MessageType) -> Void
    
    private let quickActions: [MessageType] = [.blue, .green, .yellow, .red]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("クイックアクション")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(quickActions.indices, id: \.self) { index in
                    let action = quickActions[index]
                    Button(action: { onAction(action) }) {
                        Text(getButtonText(for: action))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(action.color)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
    
    // Helper function to get button text for message types
    private func getButtonText(for messageType: MessageType) -> String {
        switch messageType {
        case .general: return ""
        case .blue: return UserDefaults.standard.string(forKey: "quickActionBlue") ?? "作業を開始しました"
        case .green: return UserDefaults.standard.string(forKey: "quickActionGreen") ?? "作業を完了しました"
        case .yellow: return UserDefaults.standard.string(forKey: "quickActionYellow") ?? "作業に遅れが生じています"
        case .red: return UserDefaults.standard.string(forKey: "quickActionRed") ?? "問題が発生しました。"
        }
    }
}

// MARK: - MessagesList.swift
struct MessagesList: View {
    let messages: [Message]
    let onDelete: (Message) -> Void
    
    var body: some View {
        List {
            if messages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "message")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("まだメッセージがありません")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            } else {
                ForEach(messages.indices, id: \.self) { index in
                    let message = messages[index]
                    MessageRowView(message: message, onDelete: onDelete)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - MessageRowView.swift
struct MessageRowView: View {
    let message: Message
    let onDelete: (Message) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.userName ?? "匿名")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if message.messageTypeEnum != .general {
                        Text("ステータス更新")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(message.messageTypeEnum.color)
                            .cornerRadius(4)
                    }
                    
                    Text(formatDate(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button(action: { onDelete(message) }) {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Text(message.message ?? "")
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - QRCodeDisplayView.swift
struct QRCodeDisplayView: View {
    let item: Item
    @Environment(\.presentationMode) var presentationMode
    @State private var qrCodeImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text(item.name ?? "Unknown")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("ID: \(item.itemId ?? "")")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if let qrCodeImage = qrCodeImage {
                    Image(uiImage: qrCodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay(
                            ProgressView()
                        )
                }
                
                VStack(spacing: 8) {
                    Text("QR Contains:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(generateQRContent())
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Button("QRコードを保存") {
                    saveQRCodeToPhotos()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("QRコード")
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            generateQRCode()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("保存結果"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func generateQRContent() -> String {
        guard let itemId = item.itemId else { return "" }
        // FIXED: Use proper URL format that the scanner can parse
        return "https://digitalmemotag.app/item?item_id=\(itemId)"
    }
    
    private func generateQRCode() {
        let qrContent = generateQRContent()
        guard let qrCodeData = qrContent.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
        
        filter.setValue(qrCodeData, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let qrCodeCIImage = filter.outputImage else { return }
        
        let scaleX = 200 / qrCodeCIImage.extent.size.width
        let scaleY = 200 / qrCodeCIImage.extent.size.height
        let transformedImage = qrCodeCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else { return }
        
        qrCodeImage = UIImage(cgImage: cgImage)
    }
    
    private func saveQRCodeToPhotos() {
        guard let image = qrCodeImage else {
            alertMessage = "QRコードの生成に失敗しました"
            showingAlert = true
            return
        }
        
        let saver = ImageSaver()
        saver.writeToPhotoAlbum(image: image) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "保存に失敗しました: \(error.localizedDescription)"
                } else if success {
                    self.alertMessage = "QRコードを写真に保存しました"
                } else {
                    self.alertMessage = "保存がキャンセルされました"
                }
                self.showingAlert = true
            }
        }
    }
}

// MARK: - QRScannerView.swift
struct QRScannerView: View {
    @State private var isPresentingScanner = false
    @State private var scannedItemId: String?
    @State private var showingManualEntry = false
    @State private var manualItemId = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingItemDetail = false
    @State private var foundItem: Item?
    
    @StateObject private var appwriteService = AppwriteService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(appwriteService.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(appwriteService.isConnected ? "Appwrite接続済み" : "Appwrite未接続")
                        .font(.caption)
                        .foregroundColor(appwriteService.isConnected ? .green : .red)
                }
                .padding(.top)
                
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
                
                // Buttons
                VStack(spacing: 16) {
                    Button(action: { isPresentingScanner = true }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("QRコードをスキャン")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: { showingManualEntry = true }) {
                        HStack {
                            Image(systemName: "keyboard")
                            Text("手動で製品IDを入力")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        Task {
                            await appwriteService.testConnection()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("接続テスト")
                        }
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                
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
                // Convert Item to CloudItem
                if let cloudItem = item.toCloudItem() {
                    NavigationView {
                        CloudItemDetailView(item: cloudItem, dataManager: CloudDataManager.shared)
                            .navigationBarItems(trailing: Button("閉じる") {
                                showingItemDetail = false
                            })
                    }
                } else {
                    // Fallback if conversion fails
                    Text("製品データの変換に失敗しました")
                        .padding()
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
    }
    
    private func handleScannedCode(_ code: String) {
        print("📱 Scanned code: \(code)")
        
        let itemId = extractItemId(from: code)
        print("🔍 Extracted item ID: \(itemId)")
        
        Task {
            await processScannedItem(itemId: itemId)
        }
    }
    
    private func extractItemId(from code: String) -> String {
        print("🔍 Processing code: \(code)")
        
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
        }
        
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ Using code as item ID: \(trimmedCode)")
        return trimmedCode
    }
    
    private func processScannedItem(itemId: String) async {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(format: "itemId == %@", itemId)
        
        do {
            let items = try context.fetch(request)
            if let item = items.first {
                await MainActor.run {
                    foundItem = item
                    item.markAsViewed()
                    showingItemDetail = true
                    alertMessage = "製品「\(item.name ?? "")」が見つかりました（ローカル）"
                    print("✅ Found item in Core Data: \(item.name ?? "")")
                }
                return
            }
            
            print("🌐 Item not in Core Data, checking Appwrite...")
            
            if let appwriteItemData = try? await AppwriteService.shared.getItem(itemId: itemId) {
                await MainActor.run {
                    let newItem = Item(context: context)
                    newItem.id = UUID()
                    newItem.itemId = itemId
                    newItem.name = appwriteItemData["name"] as? String ?? "Unknown Product"
                    newItem.location = appwriteItemData["location"] as? String ?? ""
                    newItem.status = appwriteItemData["status"] as? String ?? "Working"
                    newItem.createdAt = Date()
                    newItem.updatedAt = Date()
                    
                    do {
                        try context.save()
                        foundItem = newItem
                        showingItemDetail = true
                        alertMessage = "製品「\(newItem.name ?? "")」が見つかりました（Appwriteから同期）"
                        print("✅ Synced item from Appwrite: \(newItem.name ?? "")")
                    } catch {
                        alertMessage = "データの保存に失敗しました: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            } else {
                await MainActor.run {
                    alertMessage = "製品ID「\(itemId)」が見つかりません。"
                    showingAlert = true
                    print("❌ Item not found: \(itemId)")
                }
            }
            
        } catch {
            await MainActor.run {
                alertMessage = "データベースエラーが発生しました: \(error.localizedDescription)"
                showingAlert = true
                print("❌ Database error: \(error)")
            }
        }
    }
}
