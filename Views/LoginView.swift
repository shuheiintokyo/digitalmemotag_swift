//
//  LoginView.swift
//  digitalmemotag
//
//  Enhanced with credential storage and biometric authentication
//

import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userName = ""
    @State private var isRegistering = false
    @State private var showingForgotPassword = false
    @State private var showingAlert = false
    @State private var rememberMe = false
    @State private var showingBiometricPrompt = false
    
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
                    
                    // Biometric Authentication Section
                    if !isRegistering && authService.isBiometricAvailable() && authService.biometricAuthEnabled && !authService.savedUsername.isEmpty {
                        BiometricLoginSection(authService: authService)
                    }
                    
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
                                .textContentType(.oneTimeCode)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
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
                                    .textContentType(.oneTimeCode)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($focusedField, equals: .confirmPassword)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        Task { await handleRegistration() }
                                    }
                            }
                        }
                        
                        // Remember Me Toggle (only for login)
                        if !isRegistering {
                            HStack {
                                Toggle("ログイン情報を記憶", isOn: $rememberMe)
                                    .font(.caption)
                                
                                Spacer()
                                
                                if authService.isBiometricAvailable() && rememberMe {
                                    Button("生体認証を設定") {
                                        showingBiometricPrompt = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Auto-fill saved credentials
                    if !isRegistering && !authService.savedUsername.isEmpty {
                        Button("保存済み: \(authService.savedUsername)") {
                            email = authService.savedUsername
                            if let savedPassword = authService.getSavedPassword(for: authService.savedUsername) {
                                password = savedPassword
                                rememberMe = true
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 30)
                    }
                    
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
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                focusedField = nil
            }
        }
        .onAppear {
            // Auto-fill saved credentials if available
            if !authService.savedUsername.isEmpty {
                email = authService.savedUsername
                rememberMe = authService.rememberCredentials
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
        .alert("生体認証を設定", isPresented: $showingBiometricPrompt) {
            Button("設定する") {
                authService.toggleBiometricAuth(true)
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("\(authService.getBiometricType())を使用して次回から簡単にログインできます。")
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
            password: password,
            rememberMe: rememberMe
        )
        
        if success {
            // Show biometric setup prompt if conditions are met
            if rememberMe && authService.isBiometricAvailable() && !authService.biometricAuthEnabled {
                showingBiometricPrompt = true
            }
            print("Login successful")
        }
    }
    
    private func handleRegistration() async {
        guard isFormValid else { return }
        
        let success = await authService.register(
            email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            name: userName.isEmpty ? nil : userName.trimmingCharacters(in: .whitespacesAndNewlines),
            rememberMe: rememberMe
        )
        
        if success {
            print("Registration successful")
        }
    }
    
    private func clearForm() {
        email = authService.savedUsername // Keep saved username
        password = ""
        confirmPassword = ""
        userName = ""
        authService.errorMessage = nil
        focusedField = nil
    }
}

// MARK: - Biometric Login Section

struct BiometricLoginSection: View {
    @ObservedObject var authService: AuthenticationService
    
    var body: some View {
        VStack(spacing: 16) {
            Text("簡単ログイン")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button(action: {
                Task {
                    let success = await authService.authenticateWithBiometrics()
                    if !success {
                        // Handle failure if needed
                        print("Biometric authentication failed")
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: authService.getBiometricType() == "Face ID" ? "faceid" : "touchid")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("\(authService.getBiometricType())でログイン")
                            .font(.headline)
                        Text(authService.savedUsername)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .disabled(authService.isLoading)
            
            Divider()
                .padding(.horizontal, 20)
            
            Text("または手動でログイン")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Custom Text Field Style (keep existing)

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .font(.body)
    }
}

// MARK: - Forgot Password View (keep existing)

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
