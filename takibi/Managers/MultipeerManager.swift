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
    private let myPeerID: MCPeerID
    
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    @Published var isConnected = false
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedMessages: [ChatMessage] = []
    @Published var shouldAutoConnect = false
    
    override init() {
        // サービスタイプは固定
        self.serviceType = "takibi-chat"
        
        // PeerIDにタイムスタンプを追加してユニーク化
        let timestamp = Int(Date().timeIntervalSince1970)
        let deviceName = UIDevice.current.name
        self.myPeerID = MCPeerID(displayName: "\(deviceName)-\(timestamp)")
        
        super.init()
        
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional)
        session.delegate = self
        
        print("📱 Peer created: \(myPeerID.displayName)")
        print("🔧 Service type: \(serviceType)")
    }
    
    deinit {
        stopHosting()
        stopBrowsing()
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
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }
    
    func disconnect() {
        session.disconnect()
        isConnected = false
        connectedPeers.removeAll()
        availablePeers.removeAll()
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
        guard !connectedPeers.isEmpty else { return }
        
        let message = ChatMessage(content: text, senderID: myPeerID.displayName, isFromMe: true)
        receivedMessages.append(message)
        
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: connectedPeers, with: .reliable)
            print("📤 Message sent: \(text)")
        } catch {
            print("Error sending message: \(error)")
        }
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
            case .connecting:
                print("🔄 Connecting to: \(peerID.displayName)")
            case .notConnected:
                if let index = self.connectedPeers.firstIndex(of: peerID) {
                    self.connectedPeers.remove(at: index)
                }
                self.isConnected = !self.connectedPeers.isEmpty
                print("❌ Disconnected from: \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            var message = try JSONDecoder().decode(ChatMessage.self, from: data)
            // 受信したメッセージは必ず相手からのものなので isFromMe = false に設定
            let receivedMessage = ChatMessage(content: message.content, senderID: message.senderID, isFromMe: false)
            DispatchQueue.main.async {
                self.receivedMessages.append(receivedMessage)
                print("📥 Message received: \(message.content)")
            }
        } catch {
            print("Error decoding message: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
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
            
            // 自分自身は除外
            if peerID.displayName == self.myPeerID.displayName {
                print("⚠️ Skipping self peer: \(peerID.displayName)")
                return
            }
            
            // タイムスタンプベースの古いピア除外
            if self.isOldPeer(peerID: peerID) {
                print("⚠️ Skipping old peer: \(peerID.displayName)")
                return
            }
            
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
    
    // 古いピアかどうかを判定するヘルパーメソッド
    private func isOldPeer(peerID: MCPeerID) -> Bool {
        let components = peerID.displayName.components(separatedBy: "-")
        
        // タイムスタンプが含まれていない場合は古いピアとして扱う
        guard let timestampString = components.last,
              let peerTimestamp = Int(timestampString) else {
            return true
        }
        
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let ageDifference = currentTimestamp - peerTimestamp
        
        // 60秒以上古いピアは除外
        return ageDifference > 60
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
}
