//
//  ContentView.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject var multipeerManager: MultipeerManager
    @State private var showingConnectionView = false
    
    var body: some View {
        NavigationView {
            if multipeerManager.isConnected {
                ChatView(multipeerManager: multipeerManager)
            } else {
                ConnectionView(multipeerManager: multipeerManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ConnectionView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @State private var isHosting = false
    @State private var isBrowsing = false
    @State private var showingQRCode = false
    @State private var showingQRScanner = false
    @State private var showingUserSettings = false
    @State private var scannedCode = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Takibi Chat")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Connect with nearby devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 15) {
                Button(action: {
                    if isHosting {
                        multipeerManager.stopHosting()
                        isHosting = false
                    } else {
                        multipeerManager.startHosting()
                        isHosting = true
                    }
                }) {
                    HStack {
                        Image(systemName: isHosting ? "stop.circle" : "wifi")
                        Text(isHosting ? "Stop Hosting" : "Host Chat Room")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isHosting ? Color.red : Color.blue)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    if isBrowsing {
                        multipeerManager.stopBrowsing()
                        isBrowsing = false
                    } else {
                        multipeerManager.startBrowsing()
                        isBrowsing = true
                    }
                }) {
                    HStack {
                        Image(systemName: isBrowsing ? "stop.circle" : "magnifyingglass")
                        Text(isBrowsing ? "Stop Searching" : "Find Chat Rooms")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isBrowsing ? Color.red : Color.green)
                    .cornerRadius(10)
                }
                
                // QRコード機能ボタンを追加
                HStack(spacing: 15) {
                    Button(action: {
                        showingQRCode = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode")
                            Text("Show QR")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showingQRScanner = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Scan QR")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                }
            }
            
            if !multipeerManager.availablePeers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Available Devices:")
                        .font(.headline)
                    
                    ForEach(multipeerManager.availablePeers, id: \.self) { peer in
                        Button(action: {
                            multipeerManager.invite(peer: peer)
                        }) {
                            HStack {
                                Image(systemName: "person.circle")
                                Text(peer.displayName)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.top)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Connect")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingUserSettings = true
                }) {
                    // 現在のユーザープロフィールのアイコンを表示
                    let profile = multipeerManager.userProfileManager.currentProfile
                    ProfileImageView(profile: profile, size: 28)
                }
            }
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeDisplayView()
                .environmentObject(multipeerManager)
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView(scannedCode: $scannedCode)
        }
        .sheet(isPresented: $showingUserSettings) {
            UserSettingsView(profileManager: multipeerManager.userProfileManager)
                .onDisappear {
                    // プロフィール変更後にPeerIDを更新
                    multipeerManager.updateProfileAndReconnect()
                }
        }
        .onChange(of: scannedCode) { oldValue, newValue in
            if !newValue.isEmpty {
                print("📲 QR Code scanned: \(newValue)")
                
                // QRコードスキャン後の処理を改善
                multipeerManager.handleScannedQRCode(newValue)
                
                // UI状態をリセット
                scannedCode = ""
                showingQRScanner = false
                
                // ホスティング状態を同期（MultipeerManagerで自動的に開始されるため）
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isHosting = true
                    isBrowsing = true
                }
            }
        }
        .onChange(of: multipeerManager.isConnected) { oldValue, isConnected in
            // 接続が確立されたら自動的にモーダルを閉じる
            print("🔄 isConnected changed to: \(isConnected)")
            if isConnected {
                print("🎉 Connection established! Closing modals and transitioning to chat...")
                showingQRCode = false
                showingQRScanner = false
            }
        }
    }
}

struct ChatView: View {
    @ObservedObject var multipeerManager: MultipeerManager
    @State private var messageText = ""
    @State private var showingUserSettings = false
    @State private var isShowingPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack {
            // Header with connected peers
            HStack {
                Image(systemName: "person.2.circle.fill")
                    .foregroundColor(.green)
                Text("Connected: \(multipeerManager.connectedPeers.count)")
                    .font(.subheadline)
                Spacer()
                Button("Disconnect") {
                    multipeerManager.disconnect()
                }
                .foregroundColor(.red)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Messages list - 新しいMessageRowViewを使用
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(multipeerManager.receivedMessages) { message in
                            MessageRowView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.05))
                .onChange(of: multipeerManager.receivedMessages.count) { _, _ in
                    // 新しいメッセージが追加されたら自動的に最下部にスクロール
                    if let lastMessage = multipeerManager.receivedMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input area with photo preview
            VStack(spacing: 8) {
                // 選択した画像のプレビュー
                if let imageData = selectedImageData, let image = UIImage(data: imageData) {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 100)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Button(action: {
                            selectedImageData = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Message input with improved keyboard handling
                HStack {
                    // 写真選択ボタン
                    Button(action: {
                        isShowingPhotoPicker = true
                    }) {
                        Image(systemName: "photo.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    }
                    
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            sendMessage()
                        }
                        .submitLabel(.send)
                        // キーボード入力の問題を回避するための設定
                        .autocorrectionDisabled(false)
                        .textInputAutocapitalization(.sentences)
                        // 絵文字検索の問題を回避
                        .keyboardType(.default)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(canSendMessage ? Color.blue : Color.gray)
                            .clipShape(Circle())
                    }
                    .disabled(!canSendMessage)
                }
                .padding()
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingUserSettings = true
                }) {
                    // 現在のユーザープロフィールのアイコンを表示
                    let profile = multipeerManager.userProfileManager.currentProfile
                    ProfileImageView(profile: profile, size: 28)
                }
            }
        }
        .sheet(isPresented: $showingUserSettings) {
            UserSettingsView(profileManager: multipeerManager.userProfileManager)
                .onDisappear {
                    // プロフィール変更後にPeerIDを更新
                    multipeerManager.updateProfileAndReconnect()
                }
        }
        // キーボードが表示されたときの処理を改善
        .onTapGesture {
            // キーボード以外の場所をタップしたらフォーカスを外す
            isTextFieldFocused = false
        }
        // アプリがバックグラウンドに移行する際のキーボード状態管理
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            isTextFieldFocused = false
        }
        // 写真選択機能
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }
    
    // 送信可能かどうかを判定する計算プロパティ
    private var canSendMessage: Bool {
        return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
    }
    
    private func sendMessage() {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if let imageData = selectedImageData {
            if hasText {
                // 画像とテキストの組み合わせメッセージを送信
                multipeerManager.sendImageWithTextMessage(imageData: imageData, text: messageText)
            } else {
                // 画像のみを送信
                multipeerManager.sendImageMessage(imageData: imageData)
            }
            selectedImageData = nil
        } else if hasText {
            // テキストのみを送信
            multipeerManager.sendMessage(messageText)
        }
        
        if hasText {
            messageText = ""
        }
        
        // メッセージ送信後もフォーカスを維持
        isTextFieldFocused = true
    }
}

#Preview {
    ContentView()
}
