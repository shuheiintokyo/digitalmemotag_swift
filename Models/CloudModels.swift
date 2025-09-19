//
//  CloudModels.swift
//  digitalmemotag
//
//  Cloud-first data models for multi-device synchronization
//

import Foundation
import SwiftUI

// MARK: - CloudItem Model
struct CloudItem: Identifiable, Hashable {
    let id: String           // Appwrite document ID
    let itemId: String       // Your custom item ID (e.g., "20250115-01")
    let name: String
    let location: String
    var status: ItemStatus
    let createdAt: Date
    var updatedAt: Date
    var messages: [CloudMessage]
    
    // MARK: - Appwrite Conversion
    static func from(appwriteData: [String: Any]) -> CloudItem? {
        guard let id = appwriteData["$id"] as? String,
              let itemId = appwriteData["item_id"] as? String,
              let name = appwriteData["name"] as? String else {
            print("❌ Failed to parse CloudItem: missing required fields")
            return nil
        }
        
        let location = appwriteData["location"] as? String ?? ""
        let statusString = appwriteData["status"] as? String ?? "Working"
        let status = ItemStatus(rawValue: statusString) ?? .working
        
        // Parse Appwrite dates (ISO 8601 format)
        let createdAt = parseAppwriteDate(appwriteData["$createdAt"] as? String) ?? Date()
        let updatedAt = parseAppwriteDate(appwriteData["$updatedAt"] as? String) ?? Date()
        
        return CloudItem(
            id: id,
            itemId: itemId,
            name: name,
            location: location,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messages: [] // Messages loaded separately
        )
    }
    
    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CloudItem, rhs: CloudItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Helper Properties
    var hasNewMessages: Bool {
        // In cloud-first, this could be based on last sync time
        // For now, simplified to check if there are any messages
        return !messages.isEmpty
    }
    
    var messageCount: Int {
        return messages.count
    }
    
    var lastActivity: Date {
        return messages.first?.createdAt ?? updatedAt
    }
}

// MARK: - CloudMessage Model
struct CloudMessage: Identifiable, Hashable {
    let id: String           // Appwrite document ID
    let itemId: String       // Reference to parent item
    let message: String
    let userName: String
    let messageType: MessageType
    let createdAt: Date
    
    // MARK: - Appwrite Conversion
    static func from(appwriteData: [String: Any]) -> CloudMessage? {
        guard let id = appwriteData["$id"] as? String,
              let itemId = appwriteData["item_id"] as? String,
              let message = appwriteData["message"] as? String,
              let userName = appwriteData["user_name"] as? String else {
            print("❌ Failed to parse CloudMessage: missing required fields")
            return nil
        }
        
        let msgTypeString = appwriteData["msg_type"] as? String ?? "general"
        let messageType = MessageType(rawValue: msgTypeString) ?? .general
        
        let createdAt = parseAppwriteDate(appwriteData["$createdAt"] as? String) ?? Date()
        
        return CloudMessage(
            id: id,
            itemId: itemId,
            message: message,
            userName: userName,
            messageType: messageType,
            createdAt: createdAt
        )
    }
    
    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CloudMessage, rhs: CloudMessage) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Helper Properties
    var isStatusUpdate: Bool {
        return messageType != .general
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var isSystemMessage: Bool {
        return userName == "システム"
    }
}

// MARK: - Sync Status Enum
enum SyncStatus {
    case idle
    case syncing
    case success
    case offline
    case error(String)
    
    var displayText: String {
        switch self {
        case .idle: return "待機中"
        case .syncing: return "同期中..."
        case .success: return "同期完了"
        case .offline: return "オフライン"
        case .error(let message): return "エラー: \(message)"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .gray
        case .syncing: return .blue
        case .success: return .green
        case .offline: return .orange
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "circle"
        case .syncing: return "arrow.clockwise"
        case .success: return "checkmark.circle"
        case .offline: return "wifi.slash"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Cloud Operation Result
enum CloudOperationResult<T> {
    case success(T)
    case failure(Error)
    case offline
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }
    
    var error: Error? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

// MARK: - Helper Functions

/// Parses Appwrite ISO 8601 date strings
private func parseAppwriteDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    // Try with fractional seconds first
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    // Fallback: try without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: dateString)
}

/// Generates a formatted date string for display
func formatDateForDisplay(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

/// Generates a relative date string (e.g., "2 minutes ago")
func formatRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Extensions for Existing Models

extension ItemStatus {
    /// Maps ItemStatus to display text in Japanese
    var localizedString: String {
        switch self {
        case .working: return "作業中"
        case .completed: return "完了"
        case .delayed: return "遅延"
        case .problem: return "問題"
        }
    }
    
    /// Maps ItemStatus to display colors
    var color: Color {
        switch self {
        case .working: return .blue
        case .completed: return .green
        case .delayed: return .yellow
        case .problem: return .red
        }
    }
    
    /// Maps ItemStatus to SF Symbols
    var icon: String {
        switch self {
        case .working: return "gearshape"
        case .completed: return "checkmark.circle"
        case .delayed: return "clock"
        case .problem: return "exclamationmark.triangle"
        }
    }
}

extension MessageType {
    /// Maps MessageType to display colors
    var color: Color {
        switch self {
        case .general: return .gray
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }
    
    /// Maps MessageType to SF Symbols
    var icon: String {
        switch self {
        case .general: return "message"
        case .blue: return "play.circle"
        case .green: return "checkmark.circle"
        case .yellow: return "clock"
        case .red: return "exclamationmark.triangle"
        }
    }
    
    /// Gets the default message text for quick actions
    var defaultMessage: String {
        switch self {
        case .general: return ""
        case .blue: return UserDefaults.standard.string(forKey: "quickActionBlue") ?? "作業を開始しました"
        case .green: return UserDefaults.standard.string(forKey: "quickActionGreen") ?? "作業を完了しました"
        case .yellow: return UserDefaults.standard.string(forKey: "quickActionYellow") ?? "作業に遅れが生じています"
        case .red: return UserDefaults.standard.string(forKey: "quickActionRed") ?? "問題が発生しました。"
        }
    }
}

// MARK: - Preview Data (for SwiftUI Previews)

#if DEBUG
extension CloudItem {
    static let preview = CloudItem(
        id: "preview-id",
        itemId: "20250119-01",
        name: "サンプル製品",
        location: "倉庫A",
        status: .working,
        createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
        updatedAt: Date().addingTimeInterval(-1800), // 30 minutes ago
        messages: [CloudMessage.preview1, CloudMessage.preview2]
    )
    
    static let previewCompleted = CloudItem(
        id: "preview-id-2",
        itemId: "20250119-02",
        name: "完了済み製品",
        location: "倉庫B",
        status: .completed,
        createdAt: Date().addingTimeInterval(-7200), // 2 hours ago
        updatedAt: Date().addingTimeInterval(-3600), // 1 hour ago
        messages: []
    )
}

extension CloudMessage {
    static let preview1 = CloudMessage(
        id: "preview-message-1",
        itemId: "20250119-01",
        message: "作業を開始しました",
        userName: "田中",
        messageType: .blue,
        createdAt: Date().addingTimeInterval(-1800) // 30 minutes ago
    )
    
    static let preview2 = CloudMessage(
        id: "preview-message-2",
        itemId: "20250119-01",
        message: "順調に進んでいます",
        userName: "山田",
        messageType: .general,
        createdAt: Date().addingTimeInterval(-900) // 15 minutes ago
    )
}
#endif
