import SwiftUI
import CoreData

struct AddItemView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var itemManager: ItemManager
    
    @State private var itemName = ""
    @State private var itemLocation = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("製品情報")) {
                    TextField("製品名", text: $itemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("保管場所（任意）", text: $itemLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(footer: Text("製品IDは自動で生成されます（例: 20250115-01）")) {
                    EmptyView()
                }
            }
            .navigationTitle("新しい製品")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("追加") {
                    addItem()
                }
                .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("入力エラー"),
                    message: Text("製品名を入力してください"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func addItem() {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = itemLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            showingAlert = true
            return
        }
        
        itemManager.createItem(name: trimmedName, location: trimmedLocation)
        presentationMode.wrappedValue.dismiss()
    }
}

