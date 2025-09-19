// MARK: - Fixed QRCodeDisplayView.swift
import SwiftUI
import UIKit

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
                
                // Show both URL formats for testing
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
                title: Text("保存完了"),
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
        
        // Scale up the image
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
        
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            alertMessage = "保存に失敗しました: \(error.localizedDescription)"
        } else {
            alertMessage = "QRコードを写真に保存しました"
        }
        showingAlert = true
    }
}

// MARK: - Fixed QRScannerView.swift
import SwiftUI
import CoreData
import AVFoundation

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
                NavigationView {
                    ItemDetailView(item: item)
                        .navigationBarItems(trailing: Button("閉じる") {
                            showingItemDetail = false
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
    }
    
    private func handleScannedCode(_ code: String) {
        print("📱 Scanned code: \(code)")
        
        // Extract item ID from code
        let itemId = extractItemId(from: code)
        print("🔍 Extracted item ID: \(itemId)")
        
        Task {
            await processScannedItem(itemId: itemId)
        }
    }
    
    private func extractItemId(from code: String) -> String {
        // FIXED: Handle multiple URL formats
        print("🔍 Processing code: \(code)")
        
        // Try URL parsing first
        if let url = URL(string: code),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            
            // Check for item_id parameter
            if let itemParam = components.queryItems?.first(where: { $0.name == "item_id" })?.value {
                print("✅ Found item_id parameter: \(itemParam)")
                return itemParam
            }
            
            // Check for item parameter (legacy)
            if let itemParam = components.queryItems?.first(where: { $0.name == "item" })?.value {
                print("✅ Found item parameter: \(itemParam)")
                return itemParam
            }
            
            // Check if it's the old format: digitalmemotag://product/ITEM_ID
            if url.scheme == "digitalmemotag" && url.host == "product" {
                let itemId = url.path.replacingOccurrences(of: "/", with: "")
                if !itemId.isEmpty {
                    print("✅ Found legacy format item ID: \(itemId)")
                    return itemId
                }
            }
        }
        
        // If not a URL, assume it's the item ID directly
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ Using code as item ID: \(trimmedCode)")
        return trimmedCode
    }
    
    private func processScannedItem(itemId: String) async {
        // First check Core Data
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(format: "itemId == %@", itemId)
        
        do {
            let items = try context.fetch(request)
            if let item = items.first {
                // Found in Core Data
                await MainActor.run {
                    foundItem = item
                    item.markAsViewed()
                    showingItemDetail = true
                    alertMessage = "製品「\(item.name ?? "")」が見つかりました（ローカル）"
                    print("✅ Found item in Core Data: \(item.name ?? "")")
                }
                return
            }
            
            // Not in Core Data, check Appwrite
            print("🌐 Item not in Core Data, checking Appwrite...")
            
            if let appwriteItemData = try? await appwriteService.getItem(itemId: itemId) {
                // Found in Appwrite, create local copy
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
                // Not found anywhere
                await MainActor.run {
                    alertMessage = "製品ID「\(itemId)」が見つかりません。\n\nローカルデータベースとAppwriteの両方で検索しましたが、該当する製品が存在しませんでした。"
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
