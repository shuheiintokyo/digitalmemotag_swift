//
//  CloudItemDetailView.swift
//  digitalmemotag
//
//  Fixed message board with proper real-time updates
//

import SwiftUI
import CoreData
import UIKit
import AVFoundation

struct CloudItemDetailView: View {
    @State var item: CloudItem  // Changed to @State to allow local updates
    @ObservedObject var dataManager: CloudDataManager
    
    @State private var newMessage = ""
    @State private var userName = ""
    @State private var showingQRCode = false
    @State private var isAddingMessage = false
    @State private var showingDeleteAlert = false
    @State private var isLoadingMessages = false
    @State private var localMessages: [CloudMessage] = []
    @State private var refreshTrigger = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Item Info Header
            CloudItemInfoHeader(item: item, showingQRCode: $showingQRCode)
            
            // Quick Action Buttons
            EnhancedQuickActionButtons(
                item: item,
                dataManager: dataManager,
                isLoading: isAddingMessage,
                onQuickAction: { messageType in
                    await handleQuickAction(messageType)
                }
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
            
            // Messages List with refresh trigger
            EnhancedMessagesList(
                messages: localMessages,
                isLoading: isLoadingMessages
            )
            .id(refreshTrigger) // Force refresh when trigger changes
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            trailing: HStack {
                Button(action: {
                    Task {
                        await loadMessages()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(isLoadingMessages ? .gray : .blue)
                }
                
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
                            // Navigate back will be handled by the navigation stack
                        }
                    }
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .onAppear {
            print("🎯 CloudItemDetailView appeared for item: \(item.itemId)")
            setupInitialData()
            Task {
                await loadMessages()
            }
        }
        .onChange(of: dataManager.items) { updatedItems in
            // Update local item when dataManager items change
            if let updatedItem = updatedItems.first(where: { $0.id == item.id }) {
                print("🔄 Updating local item from dataManager")
                item = updatedItem
                localMessages = updatedItem.messages
                refreshTrigger.toggle()
            }
        }
        .refreshable {
            await loadMessages()
        }
    }
    
    private func setupInitialData() {
        localMessages = item.messages.sorted { $0.createdAt > $1.createdAt }
        print("📝 Initial messages count: \(localMessages.count)")
    }
    
    private func loadMessages() async {
        print("📨 Loading messages for item: \(item.itemId)")
        isLoadingMessages = true
        
        do {
            let messagesData = try await AppwriteService.shared.getMessages(for: item.itemId)
            print("📦 Raw messages data count: \(messagesData.count)")
            
            let messages = messagesData.compactMap { data in
                CloudMessage.from(appwriteData: data)
            }.sorted { $0.createdAt > $1.createdAt }
            
            await MainActor.run {
                localMessages = messages
                
                // Update the item's messages
                item.messages = messages
                
                // Update in dataManager as well
                if let index = dataManager.items.firstIndex(where: { $0.id == item.id }) {
                    dataManager.items[index].messages = messages
                }
                
                // Trigger UI refresh
                refreshTrigger.toggle()
                
                print("✅ Loaded \(messages.count) messages for item: \(item.itemId)")
                isLoadingMessages = false
            }
            
        } catch {
            await MainActor.run {
                print("❌ Failed to load messages: \(error)")
                isLoadingMessages = false
            }
        }
    }
    
    private func sendMessage() async {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        print("💬 Sending message: \(newMessage)")
        isAddingMessage = true
        
        let trimmedMessage = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalUserName = trimmedUserName.isEmpty ? "匿名" : trimmedUserName
        
        // Create optimistic message for immediate UI update
        let optimisticMessage = CloudMessage(
            id: "temp-\(UUID().uuidString)",
            itemId: item.itemId,
            message: trimmedMessage,
            userName: finalUserName,
            messageType: .general,
            createdAt: Date()
        )
        
        // Add optimistic message to local state immediately
        localMessages.insert(optimisticMessage, at: 0)
        refreshTrigger.toggle() // Force UI refresh
        newMessage = "" // Clear input immediately
        
        do {
            // Send to cloud
            let messageId = try await AppwriteService.shared.postMessage(
                itemId: item.itemId,
                message: trimmedMessage,
                userName: finalUserName,
                msgType: "general"
            )
            
            print("✅ Message posted to Appwrite with ID: \(messageId)")
            
            // Remove optimistic message and reload from server to ensure consistency
            await MainActor.run {
                if let index = localMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    localMessages.remove(at: index)
                    refreshTrigger.toggle()
                }
            }
            
            // Reload all messages from server
            await loadMessages()
            
        } catch {
            print("❌ Failed to send message: \(error)")
            
            // Remove optimistic message on failure
            await MainActor.run {
                if let index = localMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    localMessages.remove(at: index)
                    refreshTrigger.toggle()
                }
                
                // Restore the message text for retry
                newMessage = trimmedMessage
            }
        }
        
        isAddingMessage = false
    }
    
    private func handleQuickAction(_ messageType: MessageType) async {
        print("🚀 Quick action triggered: \(messageType)")
        
        let message = getQuickActionMessage(for: messageType)
        let finalUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let userName = finalUserName.isEmpty ? "システム" : finalUserName
        
        // Create optimistic message
        let optimisticMessage = CloudMessage(
            id: "temp-\(UUID().uuidString)",
            itemId: item.itemId,
            message: message,
            userName: userName,
            messageType: messageType,
            createdAt: Date()
        )
        
        // Add optimistic message immediately
        localMessages.insert(optimisticMessage, at: 0)
        refreshTrigger.toggle()
        
        do {
            // Send to cloud
            let messageId = try await AppwriteService.shared.postMessage(
                itemId: item.itemId,
                message: message,
                userName: userName,
                msgType: messageType.rawValue
            )
            
            // Update item status if needed
            if messageType != .general {
                let newStatus: ItemStatus = {
                    switch messageType {
                    case .blue: return .working
                    case .green: return .completed
                    case .yellow: return .delayed
                    case .red: return .problem
                    default: return item.status
                    }
                }()
                
                try await AppwriteService.shared.updateItemStatus(itemId: item.itemId, status: newStatus.rawValue)
                
                // Update local item status
                await MainActor.run {
                    item.status = newStatus
                    
                    // Update in dataManager
                    if let index = dataManager.items.firstIndex(where: { $0.id == item.id }) {
                        dataManager.items[index].status = newStatus
                        dataManager.items[index].updatedAt = Date()
                    }
                }
            }
            
            print("✅ Quick action message posted successfully")
            
            // Remove optimistic message and reload from server
            await MainActor.run {
                if let index = localMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    localMessages.remove(at: index)
                    refreshTrigger.toggle()
                }
            }
            
            await loadMessages()
            
        } catch {
            print("❌ Failed to post quick action: \(error)")
            
            // Remove optimistic message on failure
            await MainActor.run {
                if let index = localMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    localMessages.remove(at: index)
                    refreshTrigger.toggle()
                }
            }
        }
    }
    
    private func getQuickActionMessage(for messageType: MessageType) -> String {
        switch messageType {
        case .blue: return UserDefaults.standard.string(forKey: "quickActionBlue") ?? "作業を開始しました"
        case .green: return UserDefaults.standard.string(forKey: "quickActionGreen") ?? "作業を完了しました"
        case .yellow: return UserDefaults.standard.string(forKey: "quickActionYellow") ?? "作業に遅れが生じています"
        case .red: return UserDefaults.standard.string(forKey: "quickActionRed") ?? "問題が発生しました。"
        default: return ""
        }
    }
}

// MARK: - Enhanced Components (with different names to avoid conflicts)

struct EnhancedQuickActionButtons: View {
    let item: CloudItem
    let dataManager: CloudDataManager
    let isLoading: Bool
    let onQuickAction: (MessageType) async -> Void
    
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
                            await onQuickAction(action)
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

struct EnhancedMessagesList: View {
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
                    Text("下のボタンでメッセージを追加してください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            } else {
                ForEach(messages) { message in
                    EnhancedMessageRowView(message: message)
                        .listRowSeparator(.visible)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct EnhancedMessageRowView: View {
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
                        HStack(spacing: 4) {
                            Circle()
                                .fill(message.messageType.color)
                                .frame(width: 6, height: 6)
                            
                            Text("ステータス更新")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(message.messageType.color)
                                .cornerRadius(4)
                        }
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
