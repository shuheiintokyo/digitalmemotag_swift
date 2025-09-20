// MARK: - Fixed App.swift
import SwiftUI

@main
struct digitalmemotagApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .onOpenURL { url in
                            handleIncomingURL(url)
                        }
                        .task {
                            // Initialize CloudDataManager after authentication
                            await CloudDataManager.shared.initialize()
                        }
                } else {
                    LoginView()
                        .onOpenURL { url in
                            // Handle OAuth callbacks
                            handleOAuthCallback(url)
                        }
                }
            }
            .animation(.easeInOut, value: authService.isAuthenticated) // Add smooth transition
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("Received URL: \(url)")
        
        guard url.scheme == "digitalmemotag" else { return }
        guard url.host == "product" else { return }
        
        let productId = url.lastPathComponent
        print("Product ID from URL: \(productId)")
    }
    
    private func handleOAuthCallback(_ url: URL) {
        print("OAuth callback URL: \(url)")
        
        if url.absoluteString.contains("appwrite-callback") {
            print("Appwrite OAuth callback received")
        }
    }
}

