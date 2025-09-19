import Foundation

enum AppError: Error, LocalizedError {
    case coreDataError(String)
    case qrCodeGenerationFailed
    case cameraNotAvailable
    case itemNotFound
    case appwriteConnectionFailed
    case networkError(String)
    case dataParsingError(String)
    case unexpectedError(String)
    
    var errorDescription: String? {
        switch self {
        case .coreDataError(let message):
            return "データベースエラー: \(message)"
        case .qrCodeGenerationFailed:
            return "QRコードの生成に失敗しました"
        case .cameraNotAvailable:
            return "カメラが利用できません"
        case .itemNotFound:
            return "製品が見つかりません"
        case .appwriteConnectionFailed:
            return "Appwriteサーバーに接続できません"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .dataParsingError(let message):
            return "データ解析エラー: \(message)"
        case .unexpectedError(let message):
            return "予期しないエラー: \(message)"
        }
    }
    
    var localizedDescription: String {
        return errorDescription ?? "不明なエラーが発生しました"
    }
}

// MARK: - Error Handler Utility

class ErrorHandler {
    static func handle(_ error: Error, context: String = "") {
        let errorMessage: String
        
        if let appError = error as? AppError {
            errorMessage = appError.localizedDescription
        } else if let appwriteError = error as? AppwriteError {
            errorMessage = appwriteError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        
        let fullMessage = context.isEmpty ? errorMessage : "\(context): \(errorMessage)"
        print("❌ Error: \(fullMessage)")
        
        // In a production app, you might want to send this to a logging service
        // or show a user-friendly error message
    }
    
    static func userFriendlyMessage(for error: Error) -> String {
        if let appError = error as? AppError {
            return appError.localizedDescription
        } else if let appwriteError = error as? AppwriteError {
            return appwriteError.localizedDescription
        } else {
            // Generic fallback for unknown errors
            return "申し訳ございませんが、エラーが発生しました。もう一度お試しください。"
        }
    }
}
