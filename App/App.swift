import SwiftUI

@main
struct digitalmemotagApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onOpenURL { url in
                    handleIncomingURL(url)
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
        // You'll need to implement navigation logic here
        // For example, set a @State variable that triggers navigation
    }
}
