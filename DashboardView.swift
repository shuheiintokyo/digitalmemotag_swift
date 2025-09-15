//
//  DashboardView.swift
//  digitalmemotag
//
//  Created by Shuhei Kinugasa on 2025/09/15.
//

// MARK: - DashboardView.swift
import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.createdAt, ascending: false)],
        animation: .default)
    private var items: FetchedResults<Item>
    
    @StateObject private var itemManager: ItemManager
    @State private var showingAddItem = false
    @State private var searchText = ""
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._itemManager = StateObject(wrappedValue: ItemManager(context: context))
    }
    
    var filteredItems: [Item] {
        if searchText.isEmpty {
            return Array(items)
        } else {
            return items.filter { item in
                item.name?.localizedCaseInsensitiveContains(searchText) == true ||
                item.itemId?.localizedCaseInsensitiveContains(searchText) == true ||
                item.location?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Items List
                if filteredItems.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(filteredItems, id: \.id) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                ItemRowView(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("製品一覧")
            .navigationBarItems(trailing:
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
                    .environmentObject(itemManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredItems[$0] }.forEach(itemManager.deleteItem)
        }
    }
}

// MARK: - ItemRowView.swift
struct ItemRowView: View {
    let item: Item
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(item.statusEnum.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                // Item Name and ID
                HStack {
                    Text(item.name ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if item.hasNewMessages {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("NEW")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Item ID and Location
                HStack {
                    Text("ID: \(item.itemId ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let location = item.location, !location.isEmpty {
                        Text("• \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status
                Text(item.statusEnum.localizedString)
                    .font(.caption)
                    .foregroundColor(item.statusEnum.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(item.statusEnum.color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Arrow
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SearchBar.swift
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("製品名、ID、場所で検索", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - EmptyStateView.swift
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("製品がありません")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            Text("右上の + ボタンから新しい製品を追加してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - AddItemView.swift
struct AddItemView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var itemManager: ItemManager
    
    @State private var itemName = ""
    @State private var itemLocation = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("製品情報")) {
                    TextField("製品名", text: $itemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("保管場所（任意）", text: $itemLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(footer: Text("製品IDは自動で生成されます（例: 20250115-01）")) {
                    EmptyView()
                }
            }
            .navigationTitle("新しい製品")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("追加") {
                    addItem()
                }
                .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("入力エラー"),
                    message: Text("製品名を入力してください"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func addItem() {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = itemLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            showingAlert = true
            return
        }
        
        itemManager.createItem(name: trimmedName, location: trimmedLocation)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - QRScannerView.swift
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

// MARK: - QRCodeScannerView.swift (Camera Scanner)
struct QRCodeScannerView: UIViewControllerRepresentable {
    let completion: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let controller = QRCodeScannerViewController()
        controller.completion = completion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}
}

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var completion: ((String) -> Void)?
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            completion?(stringValue)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

// MARK: - ManualEntryView.swift
struct ManualEntryView: View {
    @Binding var itemId: String
    let completion: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("製品IDを入力してください")
                    .font(.headline)
                    .padding()
                
                TextField("例: 20250115-01", text: $itemId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("アクセス") {
                    completion(itemId)
                }
                .disabled(itemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(itemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("手動入力")
            .navigationBarItems(trailing: Button("キャンセル") {
                completion("")
            })
        }
    }
}
