// MARK: - SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("quickActionBlue") private var quickActionBlue = "作業を開始しました"
    @AppStorage("quickActionGreen") private var quickActionGreen = "作業を完了しました"
    @AppStorage("quickActionYellow") private var quickActionYellow = "作業に遅れが生じています"
    @AppStorage("quickActionRed") private var quickActionRed = "問題が発生しました。"
    
    @State private var showingResetAlert = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // App Info Section with Logo
                Section {
                    HStack {
                        LogoView(size: .medium, showTagline: true)
                        
                        Spacer()
                        
                        Button("詳細") {
                            showingAbout = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                
                // Quick Action Settings
                Section(header: Text("クイックアクションボタン設定")) {
                    QuickActionSetting(
                        title: "青ボタン",
                        color: .blue,
                        text: $quickActionBlue
                    )
                    
                    QuickActionSetting(
                        title: "緑ボタン",
                        color: .green,
                        text: $quickActionGreen
                    )
                    
                    QuickActionSetting(
                        title: "黄ボタン",
                        color: .orange,
                        text: $quickActionYellow
                    )
                    
                    QuickActionSetting(
                        title: "赤ボタン",
                        color: .red,
                        text: $quickActionRed
                    )
                }
                
                // Data Management
                Section(header: Text("データ管理")) {
                    Button("設定をリセット") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                // App Information
                Section(header: Text("アプリ情報")) {
                    InfoRow(label: "バージョン", value: "1.0.0")
                    InfoRow(label: "ビルド", value: "2025.09.18")
                    InfoRow(label: "開発者", value: "DigitalMemoTag Team")
                }
            }
            .navigationTitle("設定")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("設定をリセット"),
                message: Text("すべての設定をデフォルト値に戻しますか？"),
                primaryButton: .destructive(Text("リセット")) {
                    resetSettings()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    private func resetSettings() {
        quickActionBlue = "作業を開始しました"
        quickActionGreen = "作業を完了しました"
        quickActionYellow = "作業に遅れが生じています"
        quickActionRed = "問題が発生しました。"
    }
}

// MARK: - Quick Action Setting Component
struct QuickActionSetting: View {
    let title: String
    let color: Color
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            TextField("\(title)のメッセージ", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Logo and Title
                    VStack(spacing: 20) {
                        LogoView(size: .large, showTagline: true)
                        
                        Text("Digital Memo Tag")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Description
                    VStack(spacing: 16) {
                        Text("製品管理とコミュニケーションを\nシンプルに")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        
                        Text("QRコードを使用して製品を簡単に追跡し、チームメンバーとリアルタイムでコミュニケーションを取ることができる革新的なアプリです。")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Features
                    VStack(spacing: 20) {
                        Text("主な機能")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            AboutFeatureCard(
                                icon: "qrcode.viewfinder",
                                title: "QRスキャン",
                                description: "瞬時に製品にアクセス"
                            )
                            
                            AboutFeatureCard(
                                icon: "message.circle",
                                title: "メッセージング",
                                description: "チーム間の連絡"
                            )
                            
                            AboutFeatureCard(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "ステータス管理",
                                description: "進捗の可視化"
                            )
                            
                            AboutFeatureCard(
                                icon: "bolt.circle",
                                title: "高速処理",
                                description: "素早いレスポンス"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Contact Information
                    VStack(spacing: 12) {
                        Text("開発・サポート")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            Text("DigitalMemoTag Team")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("support@digitalmemotag.com")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text("© 2025 DigitalMemoTag. All rights reserved.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("アプリについて")
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - About Feature Card
struct AboutFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(12)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
