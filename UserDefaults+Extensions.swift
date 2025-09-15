import Foundation

extension UserDefaults {
    enum Keys {
        static let quickActionBlue = "quickActionBlue"
        static let quickActionGreen = "quickActionGreen"
        static let quickActionYellow = "quickActionYellow"
        static let quickActionRed = "quickActionRed"
    }
    
    func getQuickActionText(for type: MessageType) -> String {
        switch type {
        case .blue: return string(forKey: Keys.quickActionBlue) ?? "作業を開始しました"
        case .green: return string(forKey: Keys.quickActionGreen) ?? "作業を完了しました"
        case .yellow: return string(forKey: Keys.quickActionYellow) ?? "作業に遅れが生じています"
        case .red: return string(forKey: Keys.quickActionRed) ?? "問題が発生しました。"
        default: return ""
        }
    }
}
