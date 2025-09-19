//
//  LoginView.swift
//  digitalmemotag
//
//  Authentication screen with login and registration
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userName = ""
    @State private var isRegistering = false
    @State private var showingForgotPassword = false
    @State private var showingAlert = false
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword, name
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Logo/Header
                    VStack(spacing: 16) {
                        Image(systemName: "tag.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Digital Memo Tag")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(isRegistering ? "アカウントを作成" : "ログイン")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Input Fields
                    VStack(spacing: 16) {
                        // Name field (only for registration)
                        if isRegistering {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("名前（任意）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("田中 太郎", text: $userName)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .focused($focusedField, equals: .name)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .email
                                    }
                            }
                        }
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("メールアドレス")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("email@example.com", text: $email)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .password
                                }
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            SecureField("8文字以上", text: $password)
                                .textFieldStyle(CustomTextFieldStyle())
                                .focused($focusedField, equals: .password)
                                .submitLabel(isRegistering ? .next : .done)
                                .onSubmit {
                                    if isRegistering {
                                        focusedField = .confirmPassword
                                    } else {
                                        Task { await handleLogin() }
                                    }
                                }
                        }
                        
                        // Confirm Password field (only for registration)
                        if isRegistering {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("パスワード（確認）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("パスワードを再入力", text: $confirmPassword)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .focused($focusedField, equals: .confirmPassword)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        Task { await handleRegistration() }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Error Message
                    if let errorMessage = authService.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Primary Action Button
                        Button(action: {
                            Task {
                                if isRegistering {
                                    await handleRegistration()
                                } else {
                                    await handleLogin()
                                }
                            }
                        }) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(isRegistering ? "アカウント作成" : "ログイン")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || authService.isLoading)
                        
                        // Toggle Registration/Login
                        Button(action: {
                            withAnimation {
                                isRegistering.toggle()
                                clearForm()
                            }
                        }) {
                            Text(isRegistering ? "既にアカウントをお持ちの方はこちら" : "新規アカウント作成")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                        .disabled(authService.isLoading)
                        
                        // Forgot Password (only for login)
                        if !isRegistering {
                            Button(action: { showingForgotPassword = true }) {
                                Text("パスワードを忘れた方")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .disabled(authService.isLoading)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // OAuth Options (future implementation)
                    /*
                    VStack(spacing: 16) {
                        Text("または")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            OAuthButton(provider: .google, action: {
                                Task {
                                    await authService.loginWithProvider(.google)
                                }
                            })
                            
                            OAuthButton(provider: .apple, action: {
                                Task {
                                    await authService.loginWithProvider(.apple)
                                }
                            })
                        }
                    }
                    .padding(.horizontal, 30)
                    */
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                focusedField = nil
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(isRegistering ? "登録完了" : "ログイン成功"),
                message: Text(isRegistering ? "アカウントが作成されました" : "ログインしました"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        if isRegistering {
            return !email.isEmpty &&
                   email.contains("@") &&
                   password.count >= 8 &&
                   password == confirmPassword
        } else {
            return !email.isEmpty &&
                   email.contains("@") &&
                   !password.isEmpty
        }
    }
    
    // MARK: - Actions
    
    private func handleLogin() async {
        guard isFormValid else { return }
        
        let success = await authService.login(
            email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        
        if success {
            // Navigation will be handled by the parent view observing isAuthenticated
            print("Login successful")
        }
    }
    
    private func handleRegistration() async {
        guard isFormValid else { return }
        
        let success = await authService.register(
            email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            name: userName.isEmpty ? nil : userName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        if success {
            // User is automatically logged in after registration
            print("Registration successful")
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        userName = ""
        authService.errorMessage = nil
        focusedField = nil
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .font(.body)
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var authService = AuthenticationService.shared
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "key.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("パスワードをリセット")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("登録したメールアドレスを入力してください。\nパスワードリセット用のリンクをお送りします。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("メールアドレス")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("email@example.com", text: $email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .padding(.horizontal, 30)
                
                Button(action: {
                    Task {
                        await sendResetEmail()
                    }
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("リセットメールを送信")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(email.contains("@") ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!email.contains("@") || authService.isLoading)
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationTitle("パスワードリセット")
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("送信結果"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("送信しました") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    private func sendResetEmail() async {
        let success = await authService.sendPasswordRecovery(
            email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        if success {
            alertMessage = "パスワードリセット用のメールを送信しました"
        } else {
            alertMessage = authService.errorMessage ?? "送信に失敗しました"
        }
        showingAlert = true
    }
}

// MARK: - OAuth Button Component

struct OAuthButton: View {
    let provider: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: providerIcon)
                .font(.title2)
                .foregroundColor(providerColor)
                .frame(width: 50, height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    private var providerIcon: String {
        switch provider {
        case "google": return "g.circle"    // Added quotes
        case "apple": return "apple.logo"   // Added quotes
        case "github": return "person.circle" // Added quotes
        default: return "person.circle"
        }
    }
    
    private var providerColor: Color {
        switch provider {
        case "google": return .red      // Added quotes
        case "apple": return .black     // Added quotes
        case "github": return .purple   // Added quotes
        default: return .gray
        }
    }
}

// MARK: - Preview

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
