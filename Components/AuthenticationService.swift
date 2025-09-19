//
//  AuthenticationService.swift
//  digitalmemotag
//
//  Appwrite Authentication Service - Email/Password Only
//

import Foundation
import Appwrite
import JSONCodable
import SwiftUI

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    private let client: Client
    private let account: Account
    private let databases: Databases
    
    @Published var isAuthenticated = false
    @Published var currentUser: User<[String: AnyCodable]>?
    @Published var currentSession: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {
        self.client = Client()
            .setEndpoint("https://sfo.cloud.appwrite.io/v1")
            .setProject("68cba284000aabe9c076")
        
        self.account = Account(client)
        self.databases = Databases(client)
        
        // Check for existing session on init
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Authentication Methods
    
    func register(email: String, password: String, name: String? = nil) async -> Bool {
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
    
    func login(email: String, password: String) async -> Bool {
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
        do {
            // Try to get the current user
            let user = try await account.get()
            
            self.currentUser = user
            self.isAuthenticated = true
            
            print("✅ Existing session found for user: \(user.email)")
            
        } catch {
            // No valid session
            self.isAuthenticated = false
            self.currentUser = nil
            self.currentSession = nil
            
            print("ℹ️ No existing session found")
        }
    }
    
    // MARK: - Password Recovery
    
    func sendPasswordRecovery(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await account.createRecovery(
                email: email,
                url: "https://digitalmemotag.app/recovery" // Update with your recovery URL
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
    
    // Get the client for other services
    func getClient() -> Client {
        return client
    }
}
