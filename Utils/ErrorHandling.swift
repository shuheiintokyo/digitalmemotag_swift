import Foundation

enum AppError: Error, LocalizedError {
    case coreDataError(String)
    case qrCodeGenerationFailed
    case cameraNotAvailable
    case itemNotFound
    case appwriteConnectionFailed  // Added this new case
    
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
        case .appwriteConnectionFailed:  // Added this case
            return "Appwriteサーバーに接続できません"
        }
    }
}
