//
//  ContentView.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var multipeerManager = MultipeerManager()
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
        .sheet(isPresented: $showingQRCode) {
            QRCodeDisplayView()
                .environmentObject(multipeerManager)
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView(scannedCode: $scannedCode)
        }
        .onChange(of: scannedCode) { newValue in
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
        .onChange(of: multipeerManager.isConnected) { isConnected in
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
            
            // Messages list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(multipeerManager.receivedMessages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))
            
            // Message input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(messageText.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        multipeerManager.sendMessage(messageText)
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
            }
            
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                if !message.isFromMe {
                    Text(message.senderID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .padding(12)
                    .background(message.isFromMe ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(message.isFromMe ? .white : .primary)
                    .cornerRadius(16)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isFromMe {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
