//
//  ItemDetailView.swift
//  digitalmemotag
//
//  Created by Shuhei Kinugasa on 2025/09/15.
//

// MARK: - ItemDetailView.swift (Message Board)
import SwiftUI
import CoreData

struct ItemDetailView: View {
    let item: Item
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var itemManager: ItemManager
    
    @FetchRequest private var messages: FetchedResults<Message>
    @State private var newMessage = ""
    @State private var userName = ""
    @State private var showingQRCode = false
    @State private var messageToDelete: Message?
    
    init(item: Item) {
        self.item = item
        let context = PersistenceController.shared.container.viewContext
        self._itemManager = StateObject(wrappedValue: ItemManager(context: context))
        
        self._messages = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Message.createdAt, ascending: false)],
            predicate: NSPredicate(format: "itemId == %@", item.itemId ?? ""),
            animation: .default
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Item Info Header
            ItemInfoHeader(item: item, showingQRCode: $showingQRCode)
            
            // Quick Action Buttons
            QuickActionButtons { messageType in
                handleQuickAction(messageType)
            }
            
            // Message Input
            MessageInputView(
                newMessage: $newMessage,
                userName: $userName,
                onSend: sendMessage
            )
            
            // Messages List
            MessagesList(
                messages: Array(messages),
                onDelete: { message in
                    messageToDelete = message
                }
            )
        }
        .navigationTitle(item.name ?? "製品詳細")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
            Button(action: { showingQRCode = true }) {
                Image(systemName: "qrcode")
            }
        )
        .sheet(isPresented: $showingQRCode) {
            QRCodeDisplayView(item: item)
        }
        .alert(item: $messageToDelete) { message in
            Alert(
                title: Text("メッセージを削除"),
                message: Text("このメッセージを削除してもよろしいですか？"),
                primaryButton: .destructive(Text("削除")) {
                    itemManager.deleteMessage(message)
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .onAppear {
            item.markAsViewed()
        }
    }
    
    private func handleQuickAction(_ messageType: MessageType) {
        let message = getButtonText(for: messageType)
        itemManager.addMessage(to: item, message: message, userName: "システム", type: messageType)
    }
    
    private func sendMessage() {
        let trimmedMessage = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedMessage.isEmpty {
            itemManager.addMessage(
                to: item,
                message: trimmedMessage,
                userName: trimmedUserName.isEmpty ? "匿名" : trimmedUserName,
                type: .general
            )
            newMessage = ""
        }
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
import UIKit

struct QRCodeDisplayView: View {
    let item: Item
    @Environment(\.presentationMode) var presentationMode
    @State private var qrCodeImage: UIImage?
    
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
                
                Text("製品ID: \(item.itemId ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    }
    
    private func generateQRCode() {
        guard let itemId = item.itemId else { return }
        
        // Create QR code data with item ID
//        let qrCodeData = itemId.data(using: .utf8)
        
        let qrContent = "https://digitalmemotag.app/item?item_id=ITEM_ID"
        let qrCodeData = qrContent.data(using: .utf8)
        
        guard let qrCodeData = qrCodeData,
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
        guard let image = qrCodeImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
