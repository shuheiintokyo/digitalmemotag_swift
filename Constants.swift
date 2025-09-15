import Foundation

struct Constants {
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let buttonHeight: CGFloat = 44
        static let iconSize: CGFloat = 24
    }
    
    struct Colors {
        static let working = "SystemBlue"
        static let completed = "SystemGreen"
        static let delayed = "SystemOrange"
        static let problem = "SystemRed"
    }
    
    struct Defaults {
        static let quickActions = [
            "blue": "作業を開始しました",
            "green": "作業を完了しました",
            "yellow": "作業に遅れが生じています",
            "red": "問題が発生しました。"
        ]
    }
}
