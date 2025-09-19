// MARK: - Updated DashboardView.swift (Cloud-First)
import SwiftUI

struct CloudDashboardView: View {
    @StateObject private var dataManager = CloudDataManager(context: PersistenceController.shared.container.viewContext)
    @State private var showingAddItem = false
    @State private var searchText = ""
    
    var filteredItems: [CloudItem] {
        if searchText.isEmpty {
            return dataManager.items
        } else {
            return dataManager.items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.itemId.localizedCaseInsensitiveContains(searchText) ||
                item.location.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Bar
                ConnectionStatusBar(dataManager: dataManager)
                
                // Search Bar
                CloudItemSearchField(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Items List
                if dataManager.isLoading && dataManager.items.isEmpty {
                    LoadingView(message: "製品を読み込み中...")
                } else if filteredItems.isEmpty {
                    if dataManager.items.isEmpty {
                        EmptyStateView()
                    } else {
                        SearchEmptyView()
                    }
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: CloudItemDetailView(item: item, dataManager: dataManager)) {
                                CloudItemRowView(item: item)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await dataManager.refreshData()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("製品一覧")
            .navigationBarItems(
                leading: Button(action: {
                    Task {
                        await dataManager.refreshData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(dataManager.isLoading ? .gray : .blue)
                },
                trailing: Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .disabled(dataManager.isLoading)
            )
            .sheet(isPresented: $showingAddItem) {
                CloudAddItemView(dataManager: dataManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Connection Status Bar
struct ConnectionStatusBar: View {
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

// MARK: - Cloud Add Item View
struct CloudAddItemView: View {
    let dataManager: CloudDataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var itemName = ""
    @State private var itemLocation = ""
    @State private var isCreating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("製品情報")) {
                    TextField("製品名", text: $itemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isCreating)
                    
                    TextField("保管場所（任意）", text: $itemLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isCreating)
                }
                
                if isCreating {
                    Section {
                        HStack {
                            ProgressView()
                            Text("製品を作成中...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(footer: Text("製品IDは自動で生成されます（例: 20250115-01）")) {
                    EmptyView()
                }
            }
            .navigationTitle("新しい製品")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(isCreating),
                trailing: Button("作成") {
                    Task {
                        await createItem()
                    }
                }
                .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            )
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("作成結果"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("成功") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    private func createItem() async {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = itemLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            alertMessage = "製品名を入力してください"
            showingAlert = true
            return
        }
        
        isCreating = true
        
        if let newItem = await dataManager.createItem(name: trimmedName, location: trimmedLocation) {
            alertMessage = "製品「\(newItem.name)」を作成しました"
            showingAlert = true
        } else {
            alertMessage = "製品の作成に失敗しました"
            showingAlert = true
        }
        
        isCreating = false
    }
}

// MARK: - Supporting Views

struct CloudItemRowView: View {
    let item: CloudItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(item.status.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                // Item Name and ID
                HStack {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Message count indicator
                    if !item.messages.isEmpty {
                        Text("\(item.messages.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                
                // Item ID and Location
                HStack {
                    Text("ID: \(item.itemId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !item.location.isEmpty {
                        Text("• \(item.location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status
                Text(item.status.localizedString)
                    .font(.caption)
                    .foregroundColor(item.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(item.status.color.opacity(0.1))
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

struct CloudItemInfoHeader: View {
    let item: CloudItem
    @Binding var showingQRCode: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("ID: \(item.itemId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !item.location.isEmpty {
                        Text("場所: \(item.location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(item.status.color)
                            .frame(width: 8, height: 8)
                        Text(item.status.localizedString)
                            .font(.caption)
                            .foregroundColor(item.status.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.status.color.opacity(0.1))
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

struct CloudQuickActionButtons: View {
    let item: CloudItem
    let dataManager: CloudDataManager
    let isLoading: Bool
    
    private let quickActions: [MessageType] = [.blue, .green, .yellow, .red]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("クイックアクション")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(quickActions.indices, id: \.self) { index in
                    let action = quickActions[index]
                    Button(action: {
                        Task {
                            await handleQuickAction(action)
                        }
                    }) {
                        Text(getButtonText(for: action))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isLoading ? Color.gray : action.color)
                            .cornerRadius(8)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
    
    private func handleQuickAction(_ messageType: MessageType) async {
        let message = getButtonText(for: messageType)
        await dataManager.addMessage(to: item, message: message, userName: "システム", type: messageType)
    }
    
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

struct CloudMessageInputView: View {
    @Binding var newMessage: String
    @Binding var userName: String
    let isLoading: Bool
    let onSend: () async -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
            
            VStack(spacing: 12) {
                // User name input
                TextField("ユーザー名（任意）", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 16))
                    .disabled(isLoading)
                
                // Message input
                HStack(alignment: .bottom, spacing: 12) {
                    // Text input area
                    VStack {
                        if #available(iOS 16.0, *) {
                            TextField("メッセージを入力...", text: $newMessage, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 16))
                                .frame(minHeight: 90, maxHeight: 120)
                                .lineLimit(4...6)
                                .disabled(isLoading)
                        } else {
                            // iOS 15 compatibility
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )
                                    .frame(height: 90)
                                
                                TextEditor(text: $newMessage)
                                    .font(.system(size: 16))
                                    .padding(8)
                                    .background(Color.clear)
                                    .frame(height: 90)
                                    .scrollContentBackground(.hidden)
                                    .disabled(isLoading)
                                
                                if newMessage.isEmpty {
                                    Text("メッセージを入力...")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                        .padding(.leading, 12)
                                        .padding(.top, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                    
                    // Send button
                    Button(action: {
                        Task {
                            await onSend()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? Color.gray : Color.blue)
                    .cornerRadius(22)
                    .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGray6))
    }
}

struct CloudMessagesList: View {
    let messages: [CloudMessage]
    let isLoading: Bool
    
    var body: some View {
        List {
            if isLoading && messages.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("メッセージを読み込み中...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            } else if messages.isEmpty {
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
                ForEach(messages) { message in
                    CloudMessageRowView(message: message)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct CloudMessageRowView: View {
    let message: CloudMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.userName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if message.messageType != .general {
                        Text("ステータス更新")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(message.messageType.color)
                            .cornerRadius(4)
                    }
                    
                    Text(formatDate(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(message.message)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct SearchEmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("検索結果がありません")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            Text("別のキーワードで検索してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct CloudItemSearchField: View {
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

struct CloudQRCodeDisplayView: View {
    let item: CloudItem
    @Environment(\.presentationMode) var presentationMode
    @State private var qrCodeImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("ID: \(item.itemId)")
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
                
                VStack(spacing: 8) {
                    Text("📱 アプリ内でスキャンしてください")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                    
                    Text("iPhoneカメラではなく、アプリのQRスキャン機能をご利用ください")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
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
        // Use custom URL scheme for app integration
        return "digitalmemotag://item?item_id=\(item.itemId)"
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
