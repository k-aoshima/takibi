//
//  LocalNetworkPermissionManager.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/28/25.
//

import Foundation
import MultipeerConnectivity
import UIKit

class LocalNetworkPermissionManager {
    
    static func requestLocalNetworkPermission(serviceType: String, completion: @escaping (Bool) -> Void) {
        print("🔐 Requesting Local Network Permission for service: \(serviceType)")
        
        // MCNearbyServiceAdvertiserを使用して権限ダイアログを表示
        let peerID = MCPeerID(displayName: UIDevice.current.name)
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        
        let delegate = PermissionDelegate { hasPermission in
            completion(hasPermission)
        }
        
        advertiser.delegate = delegate
        advertiser.startAdvertisingPeer()
        
        // 10秒後にタイムアウト
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            advertiser.stopAdvertisingPeer()
            delegate.cleanup()
        }
    }
    
    static func checkLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        print("🔍 Checking Local Network Permission...")
        
        // 簡単なテストサービスで権限を確認
        let testServiceType = "test-permission"
        let peerID = MCPeerID(displayName: "test-peer")
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: testServiceType)
        
        let delegate = PermissionDelegate { hasPermission in
            completion(hasPermission)
        }
        
        advertiser.delegate = delegate
        advertiser.startAdvertisingPeer()
        
        // 5秒後に停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            advertiser.stopAdvertisingPeer()
            delegate.cleanup()
        }
    }
    
    static func diagnosePermissionState() {
        print("""
        📋 Local Network Permission Diagnosis:
        - Device: \(UIDevice.current.name)
        - iOS Version: \(UIDevice.current.systemVersion)
        - Network: Checking...
        """)
    }
    
    static func resetPermissionState() {
        print("🔄 Resetting permission state (iOS handles this internally)")
        // Note: iOS manages permission state internally, this is for logging/UI purposes
    }
    
    static func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
    
    // MARK: - Permission Delegate Helper
    private class PermissionDelegate: NSObject, MCNearbyServiceAdvertiserDelegate {
        private let completion: (Bool) -> Void
        private var hasCompleted = false
        
        init(completion: @escaping (Bool) -> Void) {
            self.completion = completion
            super.init()
        }
        
        func cleanup() {
            if !hasCompleted {
                hasCompleted = true
                completion(false)
            }
        }
        
        func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
            // 招待を拒否
            invitationHandler(false, nil)
            
            if !hasCompleted {
                hasCompleted = true
                completion(true) // 権限があることを示す
            }
        }
        
        func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
            print("Permission test failed: \(error.localizedDescription)")
            
            if let nsError = error as NSError?, nsError.code == -72008 {
                // ローカルネットワーク権限なし
                if !hasCompleted {
                    hasCompleted = true
                    completion(false)
                }
            } else {
                // その他のエラーでも権限なしとして扱う
                if !hasCompleted {
                    hasCompleted = true
                    completion(false)
                }
            }
        }
    }
}
