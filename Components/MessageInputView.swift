import SwiftUI
import CoreData

// MARK: - MessageInputView.swift
struct MessageInputView: View {
    @Binding var newMessage: String
    @Binding var userName: String
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
            
            VStack(spacing: 12) {
                // User name input
                TextField("ユーザー名（任意）", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 16))
                
                // Message input - Much larger
                HStack(alignment: .bottom, spacing: 12) {
                    // Large text input area
                    VStack {
                        if #available(iOS 16.0, *) {
                            TextField("メッセージを入力...", text: $newMessage, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 16))
                                .frame(minHeight: 90, maxHeight: 120)
                                .lineLimit(4...6)
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
                    Button(action: onSend) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(22)
                    }
                    .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGray6))
    }
}
