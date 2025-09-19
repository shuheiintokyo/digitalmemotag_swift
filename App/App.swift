import SwiftUI

@main
struct digitalmemotagApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
            } else {
                LoginView()
                    .onOpenURL { url in
                        // Handle OAuth callbacks
                        handleOAuthCallback(url)
                    }
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("Received URL: \(url)")
        
        // Check if it's our app's URL scheme
        guard url.scheme == "digitalmemotag" else { return }
        guard url.host == "product" else { return }
        
        let productId = url.lastPathComponent
        print("Product ID from URL: \(productId)")
        
        // TODO: Navigate to the product page
    }
    
    private func handleOAuthCallback(_ url: URL) {
        print("OAuth callback URL: \(url)")
        
        // Handle Appwrite OAuth callbacks
        if url.absoluteString.contains("appwrite-callback") {
            // The SDK handles this automatically
            print("Appwrite OAuth callback received")
        }
    }
}
