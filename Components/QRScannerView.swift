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
            VStack(spacing: 0) {
                // Logo Header with branding
                QRScannerHeaderView()
                
                // Main content
                ScrollView {
                    VStack(spacing: 40) {
                        // Hero section with logo
                        VStack(spacing: 20) {
                            LogoView(size: .large, showTagline: true)
                            
                            Text("製品のQRコードをスキャンしてアクセス")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 20)
                        
                        // Action buttons with enhanced design
                        VStack(spacing: 20) {
                            // Primary scan button
                            Button(action: { isPresentingScanner = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("QRコードをスキャン")
                                            .font(.headline)
                                        Text("カメラでスキャン")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .opacity(0.6)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            // Secondary manual entry button
                            Button(action: { showingManualEntry = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "keyboard")
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("手動で製品IDを入力")
                                            .font(.headline)
                                        Text("IDを直接入力")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .opacity(0.6)
                                }
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Features section
                        VStack(spacing: 16) {
                            Text("機能")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                                FeatureCard(
                                    icon: "bolt.fill",
                                    title: "高速スキャン",
                                    description: "瞬時に製品を識別",
                                    color: .orange
                                )
                                
                                FeatureCard(
                                    icon: "message.fill",
                                    title: "メッセージ機能",
                                    description: "リアルタイム通信",
                                    color: .green
                                )
                                
                                FeatureCard(
                                    icon: "chart.bar.fill",
                                    title: "ステータス管理",
                                    description: "作業状況を追跡",
                                    color: .blue
                                )
                                
                                FeatureCard(
                                    icon: "location.fill",
                                    title: "位置情報",
                                    description: "製品の場所を記録",
                                    color: .purple
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
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

// MARK: - QR Scanner Header
struct QRScannerHeaderView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("QRスキャン")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("FAST SERVICE")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .tracking(1)
            }
            
            Spacer()
            
            LogoView(size: .small, showTagline: false)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .gray.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Feature Card Component
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .cornerRadius(12)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
