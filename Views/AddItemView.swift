import SwiftUI
import CoreData

struct AddItemView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var dataManager = CloudDataManager.shared
    
    @State private var itemName = ""
    @State private var itemLocation = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("製品情報")) {
                    TextField("製品名", text: $itemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isCreating)
                    
                    TextField("保管場所（任意）", text: $itemLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isCreating)
                }
                
                if isCreating {
                    Section {
                        HStack {
                            ProgressView()
                            Text("製品を作成中...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(footer: Text("製品IDは自動で生成されます（例: 20250115-01）")) {
                    EmptyView()
                }
            }
            .navigationTitle("新しい製品")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(isCreating),
                trailing: Button("追加") {
                    Task {
                        await addItem()
                    }
                }
                .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("作成結果"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertMessage.contains("成功") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func addItem() async {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = itemLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            alertMessage = "製品名を入力してください"
            showingAlert = true
            return
        }
        
        isCreating = true
        
        if let newItem = await dataManager.createItem(name: trimmedName, location: trimmedLocation) {
            alertMessage = "製品「\(newItem.name)」の作成に成功しました（ID: \(newItem.itemId)）"
            showingAlert = true
        } else {
            alertMessage = "製品の作成に失敗しました。ネットワーク接続を確認してください。"
            showingAlert = true
        }
        
        isCreating = false
    }
}
