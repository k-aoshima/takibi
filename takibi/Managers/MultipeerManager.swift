//
//  MultipeerManager.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import Foundation
import MultipeerConnectivity
import SwiftUI

class MultipeerManager: NSObject, ObservableObject {
    // アプリ固有のユニークなサービスタイプを生成
    private let serviceType: String
    private var myPeerID: MCPeerID
    
    // ユーザープロフィール管理
    private let profileManager: UserProfileManager
    
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    // クリーンアップ用のTimer
    private var cleanupTimer: Timer?
    private var connectionMonitorTimer: Timer?
    
    @Published var isConnected = false
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedMessages: [ChatMessage] = []
    @Published var shouldAutoConnect = false
    
    // 接続準備状態を管理
    private var connectionReadyStates: [MCPeerID: Bool] = [:]
    private var pendingMessages: [(message: ChatMessage, peers: [MCPeerID])] = []
    
    override init() {
        // サービスタイプは固定
        self.serviceType = "takibi-chat"
        
        // プロフィールマネージャーの初期化
        self.profileManager = UserProfileManager()
        
        // ユーザープロフィールに基づいてPeerIDを作成
        self.myPeerID = MCPeerID(displayName: self.profileManager.getPeerDisplayName())
        
        super.init()
        
        // より安定した接続設定でセッションを作成
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        
        print("📱 Peer created: \(myPeerID.displayName)")
        print("🔧 Service type: \(serviceType)")
        print("🌐 Environment: \(self.isSimulator ? "Simulator" : "Device")")
    }
    
    deinit {
        stopHosting()
        stopBrowsing()
        
        // セッションを安全に切断
        session?.disconnect()
        
        print("🧹 MultipeerManager deinitialized - all resources cleaned up")
    }
    
    // MARK: - Hosting
    func startHosting() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }
    
    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }
    
    // MARK: - Browsing
    func startBrowsing() {
        availablePeers.removeAll()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        print("🔍 Started browsing for peers")
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }
    
    // MARK: - Connection
    func invite(peer: MCPeerID) {
        // セッションの状態をチェックしてから招待を送信
        guard session != nil else {
            print("❌ Session is nil, cannot invite peer")
            return
        }
        
        print("📤 Inviting peer: \(peer.displayName)")
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    }
    
    func disconnect() {
        print("🔌 Starting disconnect process...")
        
        // セッションを安全に切断
        session.disconnect()
        
        // 状態を完全にリセット
        isConnected = false
        connectedPeers.removeAll()
        availablePeers.removeAll()
        shouldAutoConnect = false
        
        // ホスティングとブラウジングを停止
        stopHosting()
        stopBrowsing()
        
        print("🧹 Disconnect completed - all states reset")
    }
    
    // 接続失敗時の完全リセット機能を追加
    func resetConnection() {
        print("🔄 Resetting connection completely...")
        
        // 既存の接続を完全に切断
        disconnect()
        
        // セッションを新しく作成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .optional)
            self.session.delegate = self
            print("✨ New session created")
        }
    }
    
    // MARK: - QR Code
    func getConnectionQRCode() -> String {
        // デバイス名とサービスタイプを含むQRコードデータを生成
        let qrData = "takibi://connect/\(myPeerID.displayName)/\(serviceType)"
        return qrData
    }
    
    func handleScannedQRCode(_ qrCode: String) {
        guard qrCode.hasPrefix("takibi://connect/") else {
            print("❌ Invalid QR code format: \(qrCode)")
            return
        }
        
        let components = qrCode.replacingOccurrences(of: "takibi://connect/", with: "").components(separatedBy: "/")
        guard components.count >= 2 else {
            print("❌ Invalid QR code components")
            return
        }
        
        let peerName = components[0]
        let serviceType = components[1]
        
        print("📱 QR Code scanned - Peer: \(peerName), Service: \(serviceType)")
        
        // QRコードスキャン後は自動接続フラグを設定
        if serviceType == self.serviceType {
            print("🔍 Starting auto-connection process...")
            shouldAutoConnect = true
            
            // 既存のセッションをリセットして新しい接続に備える
            stopBrowsing()
            stopHosting()
            
            // availablePeersをクリア
            availablePeers.removeAll()
            
            print("⏸️ Stopped existing sessions, waiting before restart...")
            
            // 少し待ってから再開始（競合を避けるため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🚀 Starting browsing for peer: \(peerName)")
                self.startBrowsing()
                
                // ホスティングも開始（相互発見のため）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("📡 Starting hosting for mutual discovery")
                    self.startHosting()
                }
            }
        } else {
            print("❌ Service type mismatch: expected \(self.serviceType), got \(serviceType)")
        }
    }
    
    // MARK: - Messaging
    func sendMessage(_ text: String) {
        guard !connectedPeers.isEmpty else {
            print("⚠️ Cannot send message: no connected peers")
            return
        }
        
        let currentProfile = profileManager.currentProfile
        let message = ChatMessage(
            content: text,
            senderID: myPeerID.displayName,
            isFromMe: true,
            senderDisplayName: currentProfile.displayName,
            senderProfile: currentProfile
        )
        receivedMessages.append(message)
        
        // 準備が完了しているピアを特定
        let readyPeers = connectedPeers.filter { 
            connectionReadyStates[$0] == true && session.connectedPeers.contains($0)
        }
        
        if readyPeers.isEmpty {
            print("⚠️ No ready peers available, queuing message")
            pendingMessages.append((message: message, peers: connectedPeers))
            return
        }
        
        // 即座に送信
        sendMessageToPeers(message: message, peers: readyPeers)
    }
    
    private func sendMessageToPeers(message: ChatMessage, peers: [MCPeerID]) {
        // より厳密な接続状態チェック
        let validPeers = peers.filter { peer in
            return session.connectedPeers.contains(peer) && 
                   connectionReadyStates[peer] == true
        }
        
        guard !validPeers.isEmpty else {
            print("⚠️ No ready peers available, queuing message: \(message.content)")
            pendingMessages.append((message: message, peers: peers))
            return
        }
        
        // 短い遅延を追加してチャンネルの安定性を確保
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                let data = try JSONEncoder().encode(message)
                try self.session.send(data, toPeers: validPeers, with: .reliable)
                print("📤 Message sent to \(validPeers.count) peer(s): \(message.content)")
                
            } catch {
                print("⚠️ Error sending message: \(error)")
                // エラーの場合、メッセージをキューに戻す（ピア情報も含める）
                self.pendingMessages.append((message: message, peers: peers))
            }
        }
    }
    
    // MARK: - Profile Management
    func updateProfileAndReconnect() {
        print("🔄 Updating profile and reconnecting...")
        
        // 新しいプロフィール情報でPeerIDを更新
        self.myPeerID = MCPeerID(displayName: profileManager.getPeerDisplayName())
        
        // 既存の接続を切断
        disconnect()
        
        // 新しいセッションを作成（改良された設定で）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .none)
            self.session.delegate = self
            print("✨ Profile updated with new session: \(self.myPeerID.displayName)")
        }
    }
    
    // プロフィールマネージャーへのアクセサ
    var userProfileManager: UserProfileManager {
        return profileManager
    }
    
    // MARK: - Settings
    func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.isConnected = true
                if let index = self.availablePeers.firstIndex(of: peerID) {
                    self.availablePeers.remove(at: index)
                }
                print("✅ Connected to: \(peerID.displayName)")
                
                // 接続後に短い遅延を追加してチャンネルの安定化を待つ
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.connectionReadyStates[peerID] = true
                    self.processPendingMessages()
                }
                
            case .connecting:
                print("🔄 Connecting to: \(peerID.displayName)")
            case .notConnected:
                print("❌ Disconnected from: \(peerID.displayName)")
                
                // 接続していたピアを削除
                if let index = self.connectedPeers.firstIndex(of: peerID) {
                    self.connectedPeers.remove(at: index)
                }
                
                // 準備状態も削除
                self.connectionReadyStates.removeValue(forKey: peerID)
                
                // 接続状態を更新
                self.isConnected = !self.connectedPeers.isEmpty
                
            @unknown default:
                break
            }
        }
    }
    
    // データ受信処理（シンプル化）
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // セッション状態の安全性をチェック
        guard session.connectedPeers.contains(peerID) else {
            print("⚠️ Received data from disconnected peer: \(peerID.displayName)")
            return
        }
        
        do {
            let message = try JSONDecoder().decode(ChatMessage.self, from: data)
            let receivedMessage = ChatMessage(
                content: message.content,
                senderID: message.senderID,
                isFromMe: false,
                senderDisplayName: message.senderDisplayName,
                senderProfile: message.senderIconType != nil ? 
                    UserProfile(displayName: message.senderDisplayName ?? "ユーザー", iconType: message.senderIconType!) : nil
            )
            DispatchQueue.main.async {
                self.receivedMessages.append(receivedMessage)
                print("📥 Message received: \(message.content)")
            }
        } catch {
            print("⚠️ Failed to decode message from \(peerID.displayName): \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    // 接続強化のための改良されたメソッド
    private func strengthenConnection(with peerID: MCPeerID) {
        // セッション状態を確認
        guard session.connectedPeers.contains(peerID) else {
            print("⚠️ Cannot strengthen connection: peer not in connected state")
            return
        }
        
        // さらに長い遅延を追加してチャンネルの完全な準備を待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard self.session.connectedPeers.contains(peerID) else {
                print("⚠️ Peer disconnected before connection test")
                return
            }
            
            print("🔗 Attempting connection test to \(peerID.displayName)")
            let testData = "connection_test".data(using: .utf8) ?? Data()
            do {
                try self.session.send(testData, toPeers: [peerID], with: .reliable)
                print("🔗 Connection test sent to \(peerID.displayName)")
            } catch {
                print("⚠️ Failed to send connection test: \(error)")
                // 接続テストが失敗した場合、少し待ってから再試行
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.retryConnectionTest(with: peerID)
                }
            }
        }
    }
    
    // 接続テストの再試行メソッド
    private func retryConnectionTest(with peerID: MCPeerID) {
        guard session.connectedPeers.contains(peerID) else {
            print("⚠️ Peer no longer connected for retry")
            return
        }
        
        print("� Retrying connection test to \(peerID.displayName)")
        let testData = "connection_test".data(using: .utf8) ?? Data()
        do {
            try session.send(testData, toPeers: [peerID], with: .reliable)
            print("🔗 Connection test retry sent to \(peerID.displayName)")
        } catch {
            print("⚠️ Connection test retry also failed: \(error)")
            // これ以上の再試行はしない
        }
    }
    
    // 接続安定性の確認メソッド
    private func verifyConnectionStability(with peerID: MCPeerID) {
        print("🔍 Verifying connection stability with \(peerID.displayName)")
        
        // ピアがまだ接続されているかチェック
        if connectedPeers.contains(peerID) {
            // 再度接続テストを送信
            strengthenConnection(with: peerID)
        } else {
            print("⚠️ Peer \(peerID.displayName) is no longer connected")
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📩 Invitation received from: \(peerID.displayName)")
        
        // 接続状態を更新
        DispatchQueue.main.async {
            // 招待を受諾
            invitationHandler(true, self.session)
            print("✅ Invitation accepted from: \(peerID.displayName)")
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            print("❌ Advertiser failed to start: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            print("🔍 Found peer: \(peerID.displayName)")
            print("   - My peer: \(self.myPeerID.displayName)")
            print("   - My environment: \(self.isSimulator ? "Simulator" : "Device")")
            print("   - Found peer environment: \(self.getPeerEnvironment(peerID.displayName))")
            
            // 自分自身は除外
            if peerID.displayName == self.myPeerID.displayName {
                print("⚠️ Skipping self peer: \(peerID.displayName)")
                return
            }
            
            // 長時間経過した古いピアをクリーンアップ
            self.cleanupOldPeers()
            
            // 非常に古いピア（1時間以上）は除外
            if self.isVeryOldPeer(peerID: peerID) {
                print("⚠️ Skipping very old peer (>1 hour): \(peerID.displayName)")
                return
            }
            
            // クロスプラットフォーム接続の確認
            let myEnvironment = self.isSimulator ? "Simulator" : "Device"
            let peerEnvironment = self.getPeerEnvironment(peerID.displayName)
            
            print("   - Cross-platform check: My=\(myEnvironment), Peer=\(peerEnvironment)")
            
            // 同じベース名のピアが既に存在する場合、より新しいものを保持
            self.removeOldDuplicatePeers(for: peerID)
            
            // シンプルな重複チェック
            if !self.availablePeers.contains(peerID) && !self.connectedPeers.contains(peerID) {
                self.availablePeers.append(peerID)
                print("✅ Added peer to available list: \(peerID.displayName)")
                
                // QRコードスキャン後の自動接続
                if self.shouldAutoConnect {
                    print("🚀 Auto-connecting to: \(peerID.displayName)")
                    self.invite(peer: peerID)
                    self.shouldAutoConnect = false
                }
            } else {
                print("⚠️ Skipping duplicate peer: \(peerID.displayName)")
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            print("📉 Lost peer: \(peerID.displayName)")
            if let index = self.availablePeers.firstIndex(of: peerID) {
                self.availablePeers.remove(at: index)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            print("❌ Browser failed to start: \(error.localizedDescription)")
        }
    }
    
    // 同じベース名の古いピアを削除するヘルパーメソッド
    private func removeOldDuplicatePeers(for newPeer: MCPeerID) {
        let newPeerBaseName = getBaseName(from: newPeer.displayName)
        let newPeerTimestamp = getTimestamp(from: newPeer.displayName)
        
        availablePeers.removeAll { existingPeer in
            let existingBaseName = getBaseName(from: existingPeer.displayName)
            let existingTimestamp = getTimestamp(from: existingPeer.displayName)
            
            // 同じベース名で、既存のピアの方が古い場合は削除
            if existingBaseName == newPeerBaseName && existingTimestamp < newPeerTimestamp {
                print("🗑️ Removing older duplicate peer: \(existingPeer.displayName)")
                return true
            }
            return false
        }
    }
    
    // デバイス名からベース名を取得
    private func getBaseName(from displayName: String) -> String {
        let components = displayName.components(separatedBy: "-")
        return components.dropLast().joined(separator: "-")
    }
    
    // デバイス名からタイムスタンプを取得
    private func getTimestamp(from displayName: String) -> Int {
        let components = displayName.components(separatedBy: "-")
        guard let timestampString = components.last,
              let timestamp = Int(timestampString) else {
            return 0
        }
        return timestamp
    }
    
    // ピアの環境を判定するヘルパーメソッド
    private func getPeerEnvironment(_ displayName: String) -> String {
        if displayName.hasPrefix("Simulator-") {
            return "Simulator"
        } else if displayName.hasPrefix("Device-") {
            return "Device"
        } else {
            return "Unknown"
        }
    }
    
    // 環境判定のヘルパープロパティ
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - メッセージ処理
    
    // 保留中のメッセージを処理（シンプル化）
    private func processPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        
        print("📮 Processing \(pendingMessages.count) pending message(s)")
        
        for pending in pendingMessages {
            let readyPeers = pending.peers.filter { 
                connectionReadyStates[$0] == true && session.connectedPeers.contains($0)
            }
            
            if !readyPeers.isEmpty {
                sendMessageToPeers(message: pending.message, peers: readyPeers)
            }
        }
        
        pendingMessages.removeAll()
    }
    
    // セッションをリフレッシュする機能を改良
    private func refreshSession() {
        print("🔄 Refreshing session...")
        
        // 現在のセッションを安全に切断
        session.disconnect()
        
        // 短い待機後に新しいセッションを作成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // より安定した設定で新しいセッションを作成
            self.session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .none)
            self.session.delegate = self
            
            // 接続状態をリセット
            self.connectedPeers.removeAll()
            self.isConnected = false
            
            // ホスティングとブラウジングを段階的に再開
            if self.advertiser != nil {
                self.stopHosting()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startHosting()
                }
            }
            
            if self.browser != nil {
                self.stopBrowsing()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    self.startBrowsing()
                }
            }
            
            print("✨ Session refreshed with improved settings")
        }
    }
    
    // 非常に古いピア（1時間以上）を判定
    private func isVeryOldPeer(peerID: MCPeerID) -> Bool {
        let components = peerID.displayName.components(separatedBy: "-")
        
        guard let timestampString = components.last,
              let peerTimestamp = Int(timestampString) else {
            // タイムスタンプがない場合は古いピアとして扱う
            print("   - No timestamp found, treating as very old peer")
            return true
        }
        
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let ageDifference = currentTimestamp - peerTimestamp
        let oneHourInSeconds = 3600
        
        let isVeryOld = ageDifference > oneHourInSeconds
        
        if isVeryOld {
            print("   - Peer age: \(ageDifference) seconds (>1 hour)")
        }
        
        return isVeryOld
    }
    
    // 古いピアのクリーンアップ
    private func cleanupOldPeers() {
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let thirtyMinutesInSeconds = 1800
        
        let initialCount = availablePeers.count
        
        availablePeers.removeAll { peer in
            let peerTimestamp = getTimestamp(from: peer.displayName)
            let ageDifference = currentTimestamp - peerTimestamp
            
            let shouldRemove = ageDifference > thirtyMinutesInSeconds
            
            if shouldRemove {
                print("🧹 Cleaning up old peer: \(peer.displayName) (age: \(ageDifference)s)")
            }
            
            return shouldRemove
        }
        
        let removedCount = initialCount - availablePeers.count
        if removedCount > 0 {
            print("🧹 Cleaned up \(removedCount) old peers")
        }
    }
    
    // 定期的なクリーンアップを開始
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupOldPeers()
        }
    }
    
    // 接続状態監視を開始
    private func startConnectionMonitoring() {
        connectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.monitorConnectionState()
        }
    }
    
    // 接続状態の監視メソッド
    private func monitorConnectionState() {
        let actualConnectedPeers = session.connectedPeers
        let internalConnectedPeers = connectedPeers
        
        // 実際の接続と内部状態が一致しない場合
        if Set(actualConnectedPeers) != Set(internalConnectedPeers) {
            print("🔍 Connection state mismatch detected during monitoring")
            print("   - Actual connected: \(actualConnectedPeers.map { $0.displayName })")
            print("   - Internal state: \(internalConnectedPeers.map { $0.displayName })")
            
            // 状態を同期
            syncConnectionState()
        }
        
        // 接続が存在する場合の処理（軽量テストは一時的に無効化）
        if !actualConnectedPeers.isEmpty {
            print("📡 \(actualConnectedPeers.count) active connection(s) detected")
            // 軽量テストを無効化してチャンネルエラーを回避
            // for peer in actualConnectedPeers {
            //     performLightweightConnectionTest(with: peer)
            // }
        }
    }
    
    // 軽量な接続テスト
    private func performLightweightConnectionTest(with peerID: MCPeerID) {
        let testData = "ping".data(using: .utf8) ?? Data()
        do {
            try session.send(testData, toPeers: [peerID], with: .unreliable)
            // unreliableモードでのpingテストなので、エラーハンドリングは最小限に
        } catch {
            print("⚠️ Lightweight connection test failed for \(peerID.displayName): \(error)")
            // 失敗した場合は次回の監視で再チェック
        }
    }
    
    // アプリライフサイクル監視のセットアップ
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    // アプリがアクティブになったときの処理
    @objc private func appDidBecomeActive() {
        print("🌟 App became active")
        
        // セッションをリフレッシュ
        refreshSession()
    }
    
    // アプリが非アクティブになる前の処理
    @objc private func appWillResignActive() {
        print("🌙 App will resign active")
        
        // 必要に応じてクリーンアップやセッションの一時停止を実施
        // ここでは特に何もしないが、将来的な拡張ポイントとして残しておく
    }
    
    // アプリ起動時の初期セッションリフレッシュ
    private func performInitialSessionRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshSession()
        }
    }
    
    // 接続状態の同期メソッドを改良
    private func syncConnectionState() {
        print("🔍 Syncing connection state...")
        
        // セッションの実際の接続状態と内部状態を同期
        let actualConnectedPeers = session.connectedPeers
        let outdatedPeers = connectedPeers.filter { !actualConnectedPeers.contains($0) }
        
        if !outdatedPeers.isEmpty {
            print("🧹 Removing \(outdatedPeers.count) outdated peer(s) from internal state")
            for peer in outdatedPeers {
                if let index = connectedPeers.firstIndex(of: peer) {
                    connectedPeers.remove(at: index)
                }
            }
        }
        
        // 新しく接続されたピアを追加
        let newPeers = actualConnectedPeers.filter { !connectedPeers.contains($0) }
        if !newPeers.isEmpty {
            print("✨ Adding \(newPeers.count) new peer(s) to internal state")
            connectedPeers.append(contentsOf: newPeers)
        }
        
        // 接続状態を更新
        let previousConnectionState = isConnected
        isConnected = !connectedPeers.isEmpty
        
        if previousConnectionState != isConnected {
            print("🔄 Connection state changed: \(previousConnectionState) -> \(isConnected)")
        }
        
        print("📊 Connection sync complete: \(connectedPeers.count) peers connected")
        
        // 接続状態の不整合が続く場合、セッションをリフレッシュ
        if actualConnectedPeers.isEmpty && !connectedPeers.isEmpty {
            print("⚠️ Critical connection state mismatch - scheduling session refresh")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshSession()
            }
        }
    }
}
