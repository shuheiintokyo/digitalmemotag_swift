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
