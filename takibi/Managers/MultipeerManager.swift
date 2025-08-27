//
//  MultipeerManager.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import MultipeerConnectivity
import Foundation
import UIKit

class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "takibi-chat"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    
    @Published var isConnected = false
    @Published var availablePeers: [MCPeerID] = []
    @Published var receivedMessages: [ChatMessage] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var connectionError: String?
    @Published var showingError = false
    
    private var session: MCSession
    private var nearbyServiceAdvertiser: MCNearbyServiceAdvertiser
    private var nearbyServiceBrowser: MCNearbyServiceBrowser
    
    override init() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        nearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        nearbyServiceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        
        super.init()
        
        session.delegate = self
        nearbyServiceAdvertiser.delegate = self
        nearbyServiceBrowser.delegate = self
    }
    
    private func showConnectionError(_ message: String) {
        DispatchQueue.main.async {
            self.connectionError = message
            self.showingError = true
        }
    }
    
    func clearError() {
        connectionError = nil
        showingError = false
    }
    
    func startHosting() {
        nearbyServiceAdvertiser.startAdvertisingPeer()
    }
    
    func stopHosting() {
        nearbyServiceAdvertiser.stopAdvertisingPeer()
    }
    
    func startBrowsing() {
        nearbyServiceBrowser.startBrowsingForPeers()
    }
    
    func stopBrowsing() {
        nearbyServiceBrowser.stopBrowsingForPeers()
    }
    
    func invite(peer: MCPeerID) {
        nearbyServiceBrowser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    func sendMessage(_ message: String) {
        guard !session.connectedPeers.isEmpty else { return }
        
        let chatMessage = ChatMessage(content: message, senderID: myPeerID.displayName, timestamp: Date(), isFromMe: true)
        
        do {
            let data = try JSONEncoder().encode(chatMessage)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            
            DispatchQueue.main.async {
                self.receivedMessages.append(chatMessage)
            }
        } catch {
            print("Error sending message: \(error)")
            showConnectionError("メッセージの送信に失敗しました")
        }
    }
    
    func disconnect() {
        session.disconnect()
        stopHosting()
        stopBrowsing()
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.availablePeers.removeAll()
            self.connectedPeers.removeAll()
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnected = true
                self.connectedPeers = session.connectedPeers
                self.clearError()
                print("Connected to \(peerID.displayName)")
            case .connecting:
                print("Connecting to \(peerID.displayName)")
            case .notConnected:
                self.isConnected = session.connectedPeers.count > 0
                self.connectedPeers = session.connectedPeers
                print("Disconnected from \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            var chatMessage = try JSONDecoder().decode(ChatMessage.self, from: data)
            chatMessage.isFromMe = false
            DispatchQueue.main.async {
                self.receivedMessages.append(chatMessage)
            }
        } catch {
            print("Error decoding message: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used in this implementation
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used in this implementation
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used in this implementation
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Advertiser failed to start: \(error.localizedDescription)")
        
        if let nsError = error as NSError?, nsError.code == -72008 {
            showConnectionError("ローカルネットワークへのアクセス許可が必要です。\n設定 > プライバシーとセキュリティ > ローカルネットワーク で takibi を有効にしてください。")
        } else {
            showConnectionError("デバイスの公開を開始できませんでした")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.availablePeers.contains(peerID) {
                self.availablePeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.availablePeers.removeAll { $0 == peerID }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Browser failed to start: \(error.localizedDescription)")
        
        if let nsError = error as NSError?, nsError.code == -72008 {
            showConnectionError("ローカルネットワークへのアクセス許可が必要です。\n設定 > プライバシーとセキュリティ > ローカルネットワーク で takibi を有効にしてください。")
        } else {
            showConnectionError("ネットワーク検索を開始できませんでした")
        }
    }
}
