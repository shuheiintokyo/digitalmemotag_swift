import SwiftUI
import CoreData

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
