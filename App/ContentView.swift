//
//  ContentView.swift
//  digitalmemotag
//
//  Main app navigation with cloud-first architecture
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CloudDashboardView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    Text("製品一覧")
                }
                .tag(0)
            
            CloudQRScannerView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "qrcode.viewfinder" : "qrcode.viewfinder")
                    Text("QRスキャン")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "gear.circle.fill" : "gear.circle")
                    Text("設定")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .onAppear {
            // Configure tab bar appearance
            configureTabBarAppearance()
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Configure normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]
        
        // Configure selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif
