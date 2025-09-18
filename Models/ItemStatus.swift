// MARK: - ItemStatus.swift
import SwiftUI

enum ItemStatus: String, CaseIterable {
    case working = "Working"
    case completed = "Completed"
    case delayed = "Delayed"
    case problem = "Problem"
    
    var color: Color {
        switch self {
        case .working: return .blue
        case .completed: return .green
        case .delayed: return .yellow
        case .problem: return .red
        }
    }
    
    var localizedString: String {
        switch self {
        case .working: return "作業中"
        case .completed: return "完了"
        case .delayed: return "遅延"
        case .problem: return "問題"
        }
    }
}
