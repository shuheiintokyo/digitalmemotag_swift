import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("製品一覧")
                }
                .tag(0)
            
            QRScannerView()
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("QRスキャン")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Logo View with Actual Image
struct LogoView: View {
    var size: LogoSize = .medium
    var showTagline: Bool = true
    var showImageOnly: Bool = false
    
    var body: some View {
        VStack(spacing: size.spacing) {
            if showImageOnly {
                // Just the logo image
                Image("digital_memo_tag_logo") // Replace with your actual asset name
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: size.logoHeight)
            } else {
                // Full logo with text
                VStack(spacing: size.spacing / 2) {
                    // Logo Image
                    Image("digital_memo_tag_logo") // Replace with your actual asset name
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: size.logoHeight)
                    
                    // App Name (if not included in logo image)
                    if size != .small {
                        VStack(spacing: 4) {
                            Text("Digital Memo Tag")
                                .font(size.titleFont)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if showTagline {
                                Text("FAST SERVICE")
                                    .font(size.taglineFont)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                    .tracking(2)
                            }
                        }
                    }
                }
            }
        }
    }
}

enum LogoSize {
    case small, medium, large
    
    var logoHeight: CGFloat {
        switch self {
        case .small: return 30
        case .medium: return 50
        case .large: return 80
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 8
        case .large: return 12
        }
    }
    
    var titleFont: Font {
        switch self {
        case .small: return .caption
        case .medium: return .title3
        case .large: return .title
        }
    }
    
    var taglineFont: Font {
        switch self {
        case .small: return .caption2
        case .medium: return .caption
        case .large: return .subheadline
        }
    }
}

// MARK: - Extensions for Core Data
extension Item {
    var statusEnum: ItemStatus {
        get { ItemStatus(rawValue: status ?? "Working") ?? .working }
        set { status = newValue.rawValue }
    }
    
    var hasNewMessages: Bool {
        guard let messages = messages?.allObjects as? [Message] else { return false }
        return messages.contains { message in
            guard let lastViewed = UserDefaults.standard.object(forKey: "lastViewed_\(itemId ?? "")") as? Date,
                  let messageDate = message.createdAt else { return false }
            return messageDate > lastViewed
        }
    }
    
    func markAsViewed() {
        UserDefaults.standard.set(Date(), forKey: "lastViewed_\(itemId ?? "")")
    }
}

extension Message {
    var messageTypeEnum: MessageType {
        get { MessageType(rawValue: msgType ?? "general") ?? .general }
        set { msgType = newValue.rawValue }
    }
}
