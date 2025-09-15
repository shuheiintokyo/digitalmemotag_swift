import SwiftUI
import CoreData

struct ManualEntryView: View {
    @Binding var itemId: String
    let completion: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("製品IDを入力してください")
                    .font(.headline)
                    .padding()
                
                TextField("例: 20250115-01", text: $itemId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("アクセス") {
                    completion(itemId)
                }
                .disabled(itemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(itemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("手動入力")
            .navigationBarItems(trailing: Button("キャンセル") {
                completion("")
            })
        }
    }
}

