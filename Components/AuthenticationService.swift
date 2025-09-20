//
//  AuthenticationService.swift
//  digitalmemotag
//
//  Enhanced with credential storage and biometric authentication
//

import Foundation
import Appwrite
import JSONCodable
import SwiftUI
import LocalAuthentication
import Security

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    private let client: Client
    private let account: Account
    private let keychainManager = KeychainManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User<[String: AnyCodable]>?
    @Published var currentSession: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Credential storage settings
    @Published var rememberCredentials = false
    @Published var biometricAuthEnabled = false
    @Published var savedUsername = ""
    
    private init() {
        self.client = Client()
            .setEndpoint("https://sfo.cloud.appwrite.io/v1")
            .setProject("68cba284000aabe9c076")
        
        self.account = Account(client)
        
        // Load saved preferences
        loadSavedPreferences()
        
        // Check for existing session on init
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Credential Storage
    
    private func loadSavedPreferences() {
        rememberCredentials = UserDefaults.standard.bool(forKey: "rememberCredentials")
        biometricAuthEnabled = UserDefaults.standard.bool(forKey: "biometricAuthEnabled")
        savedUsername = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(rememberCredentials, forKey: "rememberCredentials")
        UserDefaults.standard.set(biometricAuthEnabled, forKey: "biometricAuthEnabled")
        UserDefaults.standard.set(savedUsername, forKey: "savedUsername")
    }
    
    func saveCredentials(email: String, password: String) {
        if rememberCredentials {
            savedUsername = email
            keychainManager.save(password, forKey: "user_password_\(email)")
            savePreferences()
            print("✅ Credentials saved securely")
        }
    }
    
    func getSavedPassword(for email: String) -> String? {
        return keychainManager.load(forKey: "user_password_\(email)")
    }
    
    func clearSavedCredentials() {
        if !savedUsername.isEmpty {
            keychainManager.delete(forKey: "user_password_\(savedUsername)")
        }
        savedUsername = ""
        rememberCredentials = false
        biometricAuthEnabled = false
        savePreferences()
        print("🗑️ Credentials cleared")
    }
    
    // MARK: - Biometric Authentication
    
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func getBiometricType() -> String {
        let context = LAContext()
        guard isBiometricAvailable() else { return "None" }
        
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometric"
        }
    }
    
    func authenticateWithBiometrics() async -> Bool {
        guard isBiometricAvailable(), biometricAuthEnabled, !savedUsername.isEmpty else {
            return false
        }
        
        let context = LAContext()
        let reason = "サインインするために\(getBiometricType())を使用してください"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                // Auto-login with saved credentials
                if let savedPassword = getSavedPassword(for: savedUsername) {
                    return await login(email: savedUsername, password: savedPassword)
                }
            }
            
            return false
            
        } catch {
            print("❌ Biometric authentication failed: \(error)")
            return false
        }
    }
    
    // MARK: - Enhanced Authentication Methods
    
    func register(email: String, password: String, name: String? = nil, rememberMe: Bool = false) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create the user account
            let user = try await account.create(
                userId: ID.unique(),
                email: email,
                password: password,
                name: name
            )
            
            // Automatically log them in after registration
            let session = try await account.createEmailPasswordSession(
                email: email,
                password: password
            )
            
            self.currentUser = user
            self.currentSession = session
            self.isAuthenticated = true
            
            // Save credentials if requested
            if rememberMe {
                self.rememberCredentials = true
                saveCredentials(email: email, password: password)
            }
            
            // Update AppwriteService with authenticated client
            AppwriteService.shared.updateClient(self.client)
            
            print("✅ User registered and logged in: \(email)")
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = parseAuthError(error)
            print("❌ Registration failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    func login(email: String, password: String, rememberMe: Bool = false) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create email session
            let session = try await account.createEmailPasswordSession(
                email: email,
                password: password
            )
            
            // Get user details
            let user = try await account.get()
            
            self.currentSession = session
            self.currentUser = user
            self.isAuthenticated = true
            
            // Save credentials if requested
            if rememberMe {
                self.rememberCredentials = true
                saveCredentials(email: email, password: password)
            }
            
            // Update AppwriteService with authenticated client
            AppwriteService.shared.updateClient(self.client)
            
            print("✅ User logged in: \(email)")
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = parseAuthError(error)
            print("❌ Login failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    func logout() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await account.deleteSession(sessionId: "current")
            
            self.currentSession = nil
            self.currentUser = nil
            self.isAuthenticated = false
            
            print("✅ User logged out")
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = "ログアウトに失敗しました"
            print("❌ Logout failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    func checkSession() async {
        // First try biometric authentication if enabled
        if biometricAuthEnabled && !savedUsername.isEmpty {
            let biometricSuccess = await authenticateWithBiometrics()
            if biometricSuccess {
                return
            }
        }
        
        // Then check for existing session
        do {
            let user = try await account.get()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                
                AppwriteService.shared.updateClient(self.client)
            }
            
            print("✅ Existing session found for user: \(user.email)")
            
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.currentSession = nil
            }
            
            print("ℹ️ No existing session found")
        }
    }
    
    // MARK: - Settings Management
    
    func toggleRememberCredentials(_ enabled: Bool) {
        rememberCredentials = enabled
        if !enabled {
            clearSavedCredentials()
        }
        savePreferences()
    }
    
    func toggleBiometricAuth(_ enabled: Bool) {
        biometricAuthEnabled = enabled
        if !enabled {
            // Keep credentials but disable biometric
            savePreferences()
        } else if rememberCredentials && !savedUsername.isEmpty {
            // Enable biometric with existing credentials
            savePreferences()
        }
    }
    
    // MARK: - Password Recovery
    
    func sendPasswordRecovery(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await account.createRecovery(
                email: email,
                url: "https://digitalmemotag.app/recovery"
            )
            
            print("✅ Password recovery email sent to: \(email)")
            isLoading = false
            return true
            
        } catch {
            errorMessage = "パスワードリセットメールの送信に失敗しました"
            print("❌ Password recovery failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseAuthError(_ error: Error) -> String {
        let errorString = error.localizedDescription
        
        if errorString.contains("401") {
            return "メールアドレスまたはパスワードが正しくありません"
        } else if errorString.contains("409") {
            return "このメールアドレスは既に登録されています"
        } else if errorString.contains("400") {
            return "入力内容を確認してください"
        } else if errorString.contains("network") {
            return "ネットワークエラー: インターネット接続を確認してください"
        } else {
            return "認証エラーが発生しました"
        }
    }
    
    func getClient() -> Client {
        return client
    }
}

// MARK: - Keychain Manager

class KeychainManager {
    private let service = "com.shuhei.digitalmemotag"
    
    func save(_ data: String, forKey key: String) {
        let data = Data(data.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("❌ Keychain save failed: \(status)")
        }
    }
    
    func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
