import SwiftUI

enum MessageType: String, CaseIterable {
    case general = "general"
    case blue = "blue"
    case green = "green"
    case yellow = "yellow"
    case red = "red"
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}
