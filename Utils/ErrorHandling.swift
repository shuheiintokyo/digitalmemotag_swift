import Foundation

enum AppError: Error, LocalizedError {
    case coreDataError(String)
    case qrCodeGenerationFailed
    case cameraNotAvailable
    case itemNotFound
    
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
        }
    }
}
