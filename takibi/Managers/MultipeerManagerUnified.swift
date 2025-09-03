//
//  MultipeerManager.swift
//  takibi
//
//  Created by GitHub Copilot on 9/4/25.
//

import Foundation
import MultipeerConnectivity

class MultipeerManager: NSObject, ObservableObject {
    // アプリ固有のユニークなサービスタイプを生成
    let serviceType: String
    var mcPeerID: MCPeerID
    
    // ユーザープロフィール管理
    let userProfileManager: UserProfileManager
    
    var mcSession: MCSession?
    var mcAdvertiser: MCNearbyServiceAdvertiser?
    var mcBrowser: MCNearbyServiceBrowser?
    
    // クリーンアップ用のTimer
    private var cleanupTimer: Timer?
    private var connectionMonitorTimer: Timer?
    
    @Published var isConnected = false
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedMessages: [ChatMessage] = []
    @Published var shouldAutoConnect = false
    @Published var isSearching = false
    @Published var scannedProfile: UserProfile?
    
    // 接続準備状態を管理
    var connectionReadyStates: [MCPeerID: Bool] = [:]
    var pendingMessages: [(message: ChatMessage, peers: [MCPeerID])] = []
    
    var userProfile: UserProfile {
        return userProfileManager.currentProfile
    }
    
    override init() {
        // サービスタイプは固定
        self.serviceType = "takibi-chat"
        
        // プロフィールマネージャーの初期化
        self.userProfileManager = UserProfileManager()
        
        // ユーザープロフィールに基づいてPeerIDを作成
        self.mcPeerID = MCPeerID(displayName: self.userProfileManager.getPeerDisplayName())
        
        super.init()
        
        // より安定した接続設定でセッションを作成
        mcSession = MCSession(peer: mcPeerID, securityIdentity: nil, encryptionPreference: .none)
        mcSession?.delegate = self
        
        print("📱 Peer created: \(mcPeerID.displayName)")
        print("🔧 Service type: \(serviceType)")
    }
    
    deinit {
        cleanupTimer?.invalidate()
        connectionMonitorTimer?.invalidate()
        mcAdvertiser?.stopAdvertisingPeer()
        mcBrowser?.stopBrowsingForPeers()
        mcSession?.disconnect()
        
        print("🧹 MultipeerManager deinitialized - all resources cleaned up")
    }
    
    // MARK: - Utility Methods
    
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    func updateUserProfile() {
        // プロフィールが更新された時にPeerIDを更新
        let newDisplayName = userProfileManager.getPeerDisplayName()
        if mcPeerID.displayName != newDisplayName {
            mcPeerID = MCPeerID(displayName: newDisplayName)
            
            // セッションを再作成
            mcSession?.disconnect()
            mcSession = MCSession(peer: mcPeerID, securityIdentity: nil, encryptionPreference: .none)
            mcSession?.delegate = self
            
            print("👤 Profile updated: \(newDisplayName)")
        }
    }
    
    // MARK: - QR Code Methods
    
    func getConnectionQRCode() -> String {
        return generateQRCode() ?? ""
    }
    
    func handleScannedQRCode(_ qrCode: String) {
        processQRCode(qrCode)
    }
    
    // MARK: - Service Methods
    
    func startHosting() {
        startService()
    }
    
    func stopHosting() {
        stopService()
    }
    
    func startBrowsing() {
        startService()
    }
    
    func stopBrowsing() {
        stopService()
    }
    
    func invite(peer: MCPeerID) {
        invitePeer(peer)
    }
    
    func disconnect() {
        disconnectAll()
    }
    
    // MARK: - Messaging
    func sendMessage(_ text: String) {
        guard !connectedPeers.isEmpty else {
            print("⚠️ Cannot send message: no connected peers")
            return
        }
        
        let currentProfile = userProfileManager.currentProfile
        let message = ChatMessage(
            text: text,
            senderID: mcPeerID.displayName,
            isFromMe: true,
            senderProfile: currentProfile
        )
        receivedMessages.append(message)
        
        sendToReadyPeers(message: message)
    }
    
    func sendImageMessage(imageData: Data) {
        guard !connectedPeers.isEmpty else {
            print("⚠️ Cannot send image: no connected peers")
            return
        }
        
        let currentProfile = userProfileManager.currentProfile
        let message = ChatMessage(
            imageData: imageData,
            senderID: mcPeerID.displayName,
            isFromMe: true,
            senderProfile: currentProfile
        )
        receivedMessages.append(message)
        
        sendToReadyPeers(message: message)
    }
    
    func sendImageWithTextMessage(imageData: Data, text: String) {
        guard !connectedPeers.isEmpty else {
            print("⚠️ Cannot send message with image: no connected peers")
            return
        }
        
        let currentProfile = userProfileManager.currentProfile
        let message = ChatMessage(
            text: text,
            imageData: imageData,
            senderID: mcPeerID.displayName,
            isFromMe: true,
            senderProfile: currentProfile
        )
        receivedMessages.append(message)
        
        sendToReadyPeers(message: message)
    }
    
    private func sendToReadyPeers(message: ChatMessage) {
        let readyPeers = connectedPeers.filter { connectionReadyStates[$0] == true }
        
        if readyPeers.isEmpty {
            print("📤 No ready peers, queuing message")
            pendingMessages.append((message: message, peers: connectedPeers))
            return
        }
        
        do {
            let messageData = try JSONEncoder().encode(message)
            
            for peer in readyPeers {
                do {
                    try mcSession?.send(messageData, toPeers: [peer], with: .reliable)
                    print("📤 Message sent to \(peer.displayName)")
                } catch {
                    print("❌ Failed to send message to \(peer.displayName): \(error)")
                }
            }
        } catch {
            print("❌ Failed to encode message: \(error)")
        }
    }
    
    private func processPendingMessages() {
        var processedMessages: [(message: ChatMessage, peers: [MCPeerID])] = []
        
        for (message, originalPeers) in pendingMessages {
            let readyPeers = originalPeers.filter { connectionReadyStates[$0] == true && connectedPeers.contains($0) }
            
            if !readyPeers.isEmpty {
                do {
                    let messageData = try JSONEncoder().encode(message)
                    for peer in readyPeers {
                        try mcSession?.send(messageData, toPeers: [peer], with: .reliable)
                    }
                    processedMessages.append((message: message, peers: originalPeers))
                    print("📤 Pending message sent to \(readyPeers.count) ready peers")
                } catch {
                    print("❌ Failed to send pending message: \(error)")
                }
            }
        }
        
        // 処理済みメッセージを削除
        for processedMessage in processedMessages {
            if let index = pendingMessages.firstIndex(where: { $0.message.id == processedMessage.message.id }) {
                pendingMessages.remove(at: index)
            }
        }
    }
    
    // MARK: - Session Management
    func startService() {
        guard !isSimulator else {
            print("🚫 Cannot start service on simulator")
            return
        }
        
        guard let session = mcSession else {
            print("❌ No session available")
            return
        }
        
        isSearching = true
        
        let profileData = userProfileManager.getProfileForDiscovery()
        
        // アドバタイザー（ホスト）として開始
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: mcPeerID, discoveryInfo: profileData, serviceType: serviceType)
        mcAdvertiser?.delegate = self
        mcAdvertiser?.startAdvertisingPeer()
        
        // ブラウザー（ゲスト）として開始
        mcBrowser = MCNearbyServiceBrowser(peer: mcPeerID, serviceType: serviceType)
        mcBrowser?.delegate = self
        mcBrowser?.startBrowsingForPeers()
        
        // 定期的なクリーンアップタイマーを開始
        startCleanupTimer()
        
        print("🔍 Started browsing and advertising for service: \(serviceType)")
    }
    
    func stopService() {
        isSearching = false
        
        mcAdvertiser?.stopAdvertisingPeer()
        mcBrowser?.stopBrowsingForPeers()
        
        mcAdvertiser = nil
        mcBrowser = nil
        
        cleanupTimer?.invalidate()
        connectionMonitorTimer?.invalidate()
        
        print("🛑 Stopped browsing and advertising")
    }
    
    func invitePeer(_ peer: MCPeerID) {
        guard let session = mcSession, let browser = mcBrowser else {
            print("❌ Cannot invite: no session or browser")
            return
        }
        
        let context = Data("invitation".utf8)
        browser.invitePeer(peer, to: session, withContext: context, timeout: 10)
        print("📨 Invited peer: \(peer.displayName)")
    }
    
    func disconnectAll() {
        mcSession?.disconnect()
        DispatchQueue.main.async {
            self.connectedPeers.removeAll()
            self.availablePeers.removeAll()
            self.connectionReadyStates.removeAll()
            self.pendingMessages.removeAll()
            self.isConnected = false
        }
        print("🔌 Disconnected from all peers")
    }
    
    private func startCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.cleanupDisconnectedPeers()
        }
        
        connectionMonitorTimer?.invalidate()
        connectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.monitorConnections()
        }
    }
    
    private func cleanupDisconnectedPeers() {
        let disconnectedPeers = availablePeers.filter { peer in
            !connectedPeers.contains(peer)
        }
        
        if !disconnectedPeers.isEmpty {
            DispatchQueue.main.async {
                for peer in disconnectedPeers {
                    if let index = self.availablePeers.firstIndex(of: peer) {
                        self.availablePeers.remove(at: index)
                    }
                }
            }
            print("🧹 Cleaned up \(disconnectedPeers.count) disconnected peers")
        }
    }
    
    private func monitorConnections() {
        for peer in connectedPeers {
            if connectionReadyStates[peer] != true {
                sendReadySignal(to: peer)
            }
        }
        
        if !pendingMessages.isEmpty {
            processPendingMessages()
        }
    }
    
    private func sendReadySignal(to peer: MCPeerID) {
        do {
            let readySignal = "READY:\(mcPeerID.displayName)".data(using: .utf8)!
            try mcSession?.send(readySignal, toPeers: [peer], with: .reliable)
        } catch {
            print("❌ Failed to send ready signal to \(peer.displayName): \(error)")
        }
    }
    
    // MARK: - QR Code Generation and Processing
    func generateQRCode() -> String? {
        let currentProfile = userProfileManager.currentProfile
        
        let qrData: [String: Any] = [
            "type": "takibi_connect",
            "peerID": mcPeerID.displayName,
            "serviceType": serviceType,
            "profile": [
                "nickname": currentProfile.nickname,
                "avatarEmoji": currentProfile.avatarEmoji,
                "statusMessage": currentProfile.statusMessage
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: qrData)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("❌ Failed to generate QR code data: \(error)")
            return nil
        }
    }
    
    func processQRCode(_ qrString: String) {
        guard let data = qrString.data(using: .utf8) else {
            print("❌ Invalid QR code format")
            return
        }
        
        do {
            if let qrData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = qrData["type"] as? String,
               type == "takibi_connect",
               let peerIDString = qrData["peerID"] as? String,
               let profileData = qrData["profile"] as? [String: Any] {
                
                let profile = UserProfile(
                    id: UUID(),
                    nickname: profileData["nickname"] as? String ?? "Unknown",
                    avatarEmoji: profileData["avatarEmoji"] as? String ?? "👤",
                    statusMessage: profileData["statusMessage"] as? String ?? ""
                )
                
                DispatchQueue.main.async {
                    self.scannedProfile = profile
                    self.shouldAutoConnect = true
                }
                
                print("📱 QR Code processed: \(profile.nickname)")
            }
        } catch {
            print("❌ Failed to process QR code: \(error)")
        }
    }
    
    // MARK: - Advertising Methods
    func startAdvertising() {
        guard !isSimulator else {
            print("🚫 Cannot advertise on simulator")
            return
        }
        
        let profileData = userProfileManager.getProfileForDiscovery()
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: mcPeerID, discoveryInfo: profileData, serviceType: serviceType)
        mcAdvertiser?.delegate = self
        mcAdvertiser?.startAdvertisingPeer()
        
        print("📡 Started advertising as: \(mcPeerID.displayName)")
    }
    
    func stopAdvertising() {
        mcAdvertiser?.stopAdvertisingPeer()
        mcAdvertiser = nil
        print("📡 Stopped advertising")
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("🟢 Connected to \(peerID.displayName)")
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.isConnected = !self.connectedPeers.isEmpty
                
                // 接続後に準備信号を送信
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.sendReadySignal(to: peerID)
                }
                
            case .connecting:
                print("🟡 Connecting to \(peerID.displayName)")
                
            case .notConnected:
                print("🔴 Disconnected from \(peerID.displayName)")
                if let index = self.connectedPeers.firstIndex(of: peerID) {
                    self.connectedPeers.remove(at: index)
                }
                self.connectionReadyStates.removeValue(forKey: peerID)
                self.isConnected = !self.connectedPeers.isEmpty
                
            @unknown default:
                print("❓ Unknown connection state for \(peerID.displayName)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // 準備信号のチェック
        if let signalString = String(data: data, encoding: .utf8),
           signalString.hasPrefix("READY:") {
            DispatchQueue.main.async {
                self.connectionReadyStates[peerID] = true
                print("✅ Peer \(peerID.displayName) is ready")
                
                // 保留中のメッセージを処理
                if !self.pendingMessages.isEmpty {
                    self.processPendingMessages()
                }
            }
            return
        }
        
        // メッセージデータの処理
        do {
            let message = try JSONDecoder().decode(ChatMessage.self, from: data)
            DispatchQueue.main.async {
                var updatedMessage = message
                updatedMessage.isFromMe = false
                self.receivedMessages.append(updatedMessage)
                print("📨 Received message from \(peerID.displayName)")
            }
        } catch {
            print("❌ Failed to decode message: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("📊 Received stream from \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didStartReceivingResource resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("📥 Started receiving resource from \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResource resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("📥 Finished receiving resource from \(peerID.displayName)")
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📨 Received invitation from \(peerID.displayName)")
        
        // 自動的に招待を受け入れる
        invitationHandler(true, mcSession)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ Failed to start advertising: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("👀 Found peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            if !self.availablePeers.contains(peerID) && peerID != self.mcPeerID {
                self.availablePeers.append(peerID)
                
                // shouldAutoConnectが有効な場合、自動的に招待
                if self.shouldAutoConnect {
                    self.invitePeer(peerID)
                    self.shouldAutoConnect = false
                }
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("👋 Lost peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            if let index = self.availablePeers.firstIndex(of: peerID) {
                self.availablePeers.remove(at: index)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Failed to start browsing: \(error.localizedDescription)")
    }
}
