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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
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
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("エラー"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func handleScannedCode(_ code: String) {
        // Extract item ID from URL or use code directly
        let itemId = extractItemId(from: code)
        
        // Check if item exists
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(format: "itemId == %@", itemId)
        
        do {
            let items = try context.fetch(request)
            if let item = items.first {
                // Navigate to item detail
                item.markAsViewed()
                scannedItemId = itemId
            } else {
                alertMessage = "製品ID「\(itemId)」が見つかりません"
                showingAlert = true
            }
        } catch {
            alertMessage = "データベースエラーが発生しました"
            showingAlert = true
        }
    }
    
    private func extractItemId(from code: String) -> String {
        // If code is a URL, extract item parameter
        if let url = URL(string: code),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let itemParam = components.queryItems?.first(where: { $0.name == "item" })?.value {
            return itemParam
        }
        // Otherwise, assume code is the item ID
        return code
    }
}
