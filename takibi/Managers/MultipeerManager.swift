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
    @Published var qrCodeImage: UIImage?
    @Published var connectionError: String?
    @Published var showingError = false
    @Published var hasLocalNetworkPermission = false
    
    private var session: MCSession
    private var nearbyServiceAdvertiser: MCNearbyServiceAdvertiser
    private var nearbyServiceBrowser: MCNearbyServiceBrowser
    private var permissionCheckAttempts = 0
    private let maxPermissionAttempts = 5
    
    override init() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        nearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        nearbyServiceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        
        super.init()
        
        session.delegate = self
        nearbyServiceAdvertiser.delegate = self
        nearbyServiceBrowser.delegate = self
        
        generateQRCode()
        
        // 実機で権限ダイアログを確実に表示させるため、即座にサービスを開始
        print("🔥 Initializing MultipeerManager - FORCING PERMISSION DIALOG NOW")
        print("📱 Device: \(UIDevice.current.name), iOS: \(UIDevice.current.systemVersion)")
        
        // 権限ダイアログを表示するため、即座にサービスを開始（遅延なし）
        forcePermissionDialogImmediately()
    }
    
    // MARK: - QR Code Functions
    func generateQRCode() {
        let connectionString = QRCodeUtility.createConnectionString(
            peerID: myPeerID.displayName,
            serviceType: serviceType
        )
        qrCodeImage = QRCodeUtility.generateQRCode(from: connectionString)
    }
    
    func connectFromQRCode(_ qrCodeString: String) {
        guard let connectionInfo = QRCodeUtility.parseConnectionString(qrCodeString) else {
            showConnectionError("無効なQRコードです")
            return
        }
        
        // QRコードから取得した情報で接続を試行
        startBrowsing()
        print("Starting to search for peer: \(connectionInfo.peerID)")
        
        // 10秒後に接続できない場合はエラーを表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            if self?.connectedPeers.isEmpty == true {
                self?.showConnectionError("QRコードのデバイスが見つかりません。\n同じネットワークに接続されているか確認してください。")
            }
        }
    }
    
    private func showConnectionError(_ message: String) {
        DispatchQueue.main.async {
            self.connectionError = message
            self.showingError = true
        }
    }
    
    private func showPermissionError() {
        let message = """
        ローカルネットワークへのアクセス許可が必要です。

        設定手順:
        1. 設定アプリを開く
        2. プライバシーとセキュリティ
        3. ローカルネットワーク
        4. takibi をオンにする

        設定後、アプリを再起動してください。
        """
        
        DispatchQueue.main.async {
            self.connectionError = message
            self.showingError = true
        }
    }
    
    func clearError() {
        connectionError = nil
        showingError = false
    }
    
    // MARK: - Local Network Permission
    func requestLocalNetworkPermissionIfNeeded() {
        permissionCheckAttempts += 1
        print("Requesting local network permission (attempt \(permissionCheckAttempts)/\(maxPermissionAttempts))...")
        
        // 最大試行回数を超えた場合
        if permissionCheckAttempts > maxPermissionAttempts {
            showPermissionExhaustedError()
            return
        }
        
        // まず権限状態を診断
        LocalNetworkPermissionManager.diagnosePermissionState()
        
        LocalNetworkPermissionManager.requestLocalNetworkPermission(serviceType: serviceType) { [weak self] hasPermission in
            DispatchQueue.main.async {
                self?.hasLocalNetworkPermission = hasPermission
                print("Permission request result: \(hasPermission)")
                if hasPermission {
                    self?.clearError()
                    self?.permissionCheckAttempts = 0 // 成功時はカウンターをリセット
                    print("Permission granted, clearing errors and starting services")
                    // 権限が取得された場合、自動的にサービスを開始
                    self?.startServicesIfPermissionGranted()
                } else {
                    // 試行回数に応じてエラーメッセージを変更
                    if self?.permissionCheckAttempts ?? 0 >= self?.maxPermissionAttempts ?? 3 {
                        self?.showPermissionExhaustedError()
                    } else {
                        self?.showPermissionError()
                        // 権限が取得できない場合、再試行を促す
                        self?.showPermissionRecoveryOptions()
                    }
                }
            }
        }
    }
    
    /// 権限要求の試行回数が上限に達した場合のエラー
    private func showPermissionExhaustedError() {
        let message = """
        🚫 ローカルネットワーク権限の取得に失敗しました
        
        📱 この問題は以下が原因の可能性があります：
        
        1️⃣ シミュレーター環境
           → 実機デバイスでテストしてください
        
        2️⃣ 権限ダイアログが表示されない
           → アプリを削除して再インストール
           → デバイスを再起動後に再試行
        
        3️⃣ ネットワーク設定の問題
           → Wi-Fi接続を確認
           → VPNを無効にして再試行
           → 別のWi-Fiネットワークで試行
        
        4️⃣ iOS設定の問題
           → 設定 > プライバシーとセキュリティ > ローカルネットワーク
           → takibiアプリを手動で有効化
        
        💡 解決策：
        • アプリを完全に削除
        • デバイスを再起動
        • アプリを再インストール
        • 初回起動時に必ず「許可」を選択
        """
        
        DispatchQueue.main.async {
            self.connectionError = message
            self.showingError = true
        }
    }
    
    // MARK: - Simulator Detection
    private func checkIfRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private func showSimulatorLimitation() {
        let message = """
        🔧 シミュレーター環境での実行

        MultipeerConnectivityはiOSシミュレーターでは制限があります：
        
        ⚠️ 制限事項：
        • ローカルネットワーク権限が正常に動作しない
        • 実際のデバイス検索ができない
        • P2P接続が制限される
        
        ✅ 推奨対応：
        1. 実機デバイスでテストする
        2. 2台以上のiOSデバイスを用意
        3. 同じWi-Fiネットワークに接続
        
        📱 実機テスト手順：
        1. Xcodeで実機を選択
        2. プロジェクトをビルド・実行
        3. 初回起動時に「ローカルネットワーク」権限を許可
        4. 別のデバイスでも同様に実行
        5. QRコードまたは自動検索で接続
        """
        
        DispatchQueue.main.async {
            self.connectionError = message
            self.showingError = true
        }
    }

    /// 権限復旧オプションを表示
    private func showPermissionRecoveryOptions() {
        let message = """
        ⚠️ ローカルネットワーク権限が取得できません
        
        権限ダイアログが表示されない場合の対処法：
        
        📱 方法1: 手動設定
        1. 設定アプリを開く
        2. プライバシーとセキュリティ
        3. ローカルネットワーク
        4. takibi をオンにする
        
        🔄 方法2: アプリリセット
        1. アプリを削除
        2. デバイスを再起動
        3. アプリを再インストール
        4. 初回起動時に「許可」を選択
        
        💡 方法3: ネットワーク確認
        - Wi-Fi接続を確認
        - VPNを無効にしてテスト
        - 他のWi-Fiネットワークで試行
        
        設定完了後、アプリを完全に再起動してください。
        """
        
        DispatchQueue.main.async {
            self.connectionError = message
            self.showingError = true
        }
    }

    /// 権限が取得された場合にサービスを開始する
    private func startServicesIfPermissionGranted() {
        guard hasLocalNetworkPermission else { return }
        
        print("Starting services with granted permission")
        // 権限取得直後は少し待ってからサービス開始
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.nearbyServiceAdvertiser.startAdvertisingPeer()
            print("Started advertising peer")
        }
    }
    
    private func startMultipeerServices() {
        print("🚀 Starting all Multipeer services with permission")
        nearbyServiceAdvertiser.startAdvertisingPeer()
        nearbyServiceBrowser.startBrowsingForPeers()
        print("✅ Multipeer services started successfully")
        
        // 権限が確認されたことをUIに反映
        DispatchQueue.main.async {
            self.hasLocalNetworkPermission = true
            self.clearError()
        }
    }
    
    /// 権限状態を強制的に再チェックする
    func recheckPermission() {
        print("Manually rechecking permission...")
        LocalNetworkPermissionManager.checkLocalNetworkPermission { [weak self] hasPermission in
            DispatchQueue.main.async {
                self?.hasLocalNetworkPermission = hasPermission
                print("Local network permission check result: \(hasPermission)")
                if !hasPermission {
                    self?.showPermissionRecoveryOptions()
                } else {
                    self?.clearError()
                    self?.startServicesIfPermissionGranted()
                }
            }
        }
    }
    
    /// 権限復旧プロセスを実行
    func recoverPermission() {
        print("🔄 Starting permission recovery process...")
        
        // 権限状態をリセットして再要求
        LocalNetworkPermissionManager.resetPermissionState()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.requestLocalNetworkPermissionIfNeeded()
        }
    }
    
    func openSettings() {
        LocalNetworkPermissionManager.openSettings()
    }
    
    func startHosting() {
        guard hasLocalNetworkPermission else {
            requestLocalNetworkPermissionIfNeeded()
            return
        }
        nearbyServiceAdvertiser.startAdvertisingPeer()
    }
    
    func stopHosting() {
        nearbyServiceAdvertiser.stopAdvertisingPeer()
    }
    
    func startBrowsing() {
        guard hasLocalNetworkPermission else {
            requestLocalNetworkPermissionIfNeeded()
            return
        }
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
            
            // Add to local messages
            DispatchQueue.main.async {
                self.receivedMessages.append(chatMessage)
            }
        } catch {
            print("Error sending message: \(error)")
        }
    }
    
    func disconnect() {
        session.disconnect()
        stopHosting()
        stopBrowsing()
    }
    
    /// 権限ダイアログを即座に強制表示（遅延なし）
    private func forcePermissionDialogImmediately() {
        print("💥 IMMEDIATE permission dialog trigger")
        print("🚨 Starting services NOW to force permission dialog")
        print("📱 CRITICAL: This should trigger Local Network permission dialog")
        
        // NSBonjourServicesに登録されたサービスタイプのみを使用
        let registeredServiceTypes = ["takibi-chat", "takibi-main", "takibi-local", "takibi-peer"]
        
        for serviceType in registeredServiceTypes {
            let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
            let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
            
            advertiser.delegate = self
            browser.delegate = self
            
            advertiser.startAdvertisingPeer()
            browser.startBrowsingForPeers()
            
            print("🔥 Started registered service: \(serviceType)")
        }
        
        // メインサービスも開始
        nearbyServiceAdvertiser.startAdvertisingPeer()
        nearbyServiceBrowser.startBrowsingForPeers()
        
        print("📢 All registered services started - Permission dialog MUST appear NOW!")
        print("👀 LOOK FOR LOCAL NETWORK PERMISSION DIALOG!")
        print("⚠️ If no dialog appears, check that NSBonjourServices is properly configured")
        
        // 1秒後に最初のチェック
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.immediatePermissionCheck()
        }
    }
    
    private func immediatePermissionCheck() {
        print("⚡ Immediate permission check after 1 second")
        print("🔍 Checking if permission dialog was shown...")
        
        // サービスがエラーなく動作しているかチェック
        if hasLocalNetworkPermission {
            print("✅ Permission dialog was accepted!")
            startMultipeerServices()
            return
        }
        
        // 3秒後に次のチェック
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.quickPermissionCheck()
        }
    }
    
    private func quickPermissionCheck() {
        print("⚡ Quick permission check after 4 seconds total")
        
        // サービスが正常に動作しているかエラーで判断
        // エラーが発生していない場合は権限が許可されている可能性
        if !hasLocalNetworkPermission {
            print("⚠️ Permission not yet confirmed, continuing services...")
            
            // さらに5秒待って再確認
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.detailedPermissionCheck()
            }
        } else {
            print("✅ Permission already granted!")
            startMultipeerServices()
        }
    }
    
    private func detailedPermissionCheck() {
        print("🔍 Detailed permission check after 9 seconds total")
        
        // LocalNetworkPermissionManagerでテスト
        LocalNetworkPermissionManager.checkLocalNetworkPermission { [weak self] hasPermission in
            DispatchQueue.main.async {
                print("📊 Detailed permission result: \(hasPermission)")
                self?.hasLocalNetworkPermission = hasPermission
                
                if hasPermission {
                    print("🎉 Permission confirmed!")
                    self?.clearError()
                    self?.startMultipeerServices()
                } else {
                    print("😔 Permission not granted yet")
                    self?.handlePermissionNotGranted()
                }
            }
        }
    }
    
    private func handlePermissionNotGranted() {
        print("🚨 Permission not granted - trying additional methods")
        
        // 追加の方法で権限ダイアログを表示
        tryAdditionalPermissionMethods()
    }
    
    private func tryAdditionalPermissionMethods() {
        print("🔧 Trying additional permission methods...")
        
        // 方法1: 異なるサービスタイプで試行
        let altServiceType = "takibi-alt"
        let altAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: altServiceType)
        altAdvertiser.delegate = self
        altAdvertiser.startAdvertisingPeer()
        
        // 方法2: 短時間で複数のサービスを開始
        let testServiceTypes = ["takibi-test1", "takibi-test2", "takibi-test3"]
        for (index, serviceType) in testServiceTypes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) { [weak self] in
                let testAdvertiser = MCNearbyServiceAdvertiser(peer: self?.myPeerID ?? MCPeerID(displayName: "test"), discoveryInfo: nil, serviceType: serviceType)
                testAdvertiser.delegate = self
                testAdvertiser.startAdvertisingPeer()
                
                // 1秒後に停止
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    testAdvertiser.stopAdvertisingPeer()
                }
            }
        }
        
        // 5秒後に最終確認
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.finalPermissionAttempt()
        }
    }
    
    private func finalPermissionAttempt() {
        print("🏁 Final permission attempt")
        
        LocalNetworkPermissionManager.checkLocalNetworkPermission { [weak self] hasPermission in
            DispatchQueue.main.async {
                self?.hasLocalNetworkPermission = hasPermission
                print("🎯 Final permission check result: \(hasPermission)")
                
                if hasPermission {
                    print("🎊 Permission finally granted!")
                    self?.clearError()
                    self?.startMultipeerServices()
                } else {
                    print("💔 Permission still not granted - showing instructions")
                    self?.showPermissionDialogNotAppearingError()
                }
            }
        }
    }
    
    private func showPermissionDialogNotAppearingError() {
        let message = """
        🚨 ローカルネットワーク権限ダイアログが表示されていません
        
        📱 **重要**: 権限ダイアログが表示されない原因
        
        1️⃣ **アプリが初回インストールではない**
           → アプリを完全に削除してから再インストール
           → ダイアログは初回インストール時のみ表示される
        
        2️⃣ **iOS設定で制限されている**
           → 設定 > スクリーンタイム > コンテンツとプライバシーの制限
           → 「ローカルネットワーク」が制限されていないか確認
        
        3️⃣ **企業・学校のデバイス管理**
           → MDM (Mobile Device Management) で制限されている可能性
           → 管理者に相談してください
        
        🔧 **即座に解決する方法**:
        
        ✅ **方法1: アプリ完全削除＆再インストール**
        1. takibiアプリを長押し → 削除
        2. iPhone/iPadを再起動
        3. Xcodeから再度インストール
        4. 初回起動時に権限ダイアログで「許可」を選択
        
        ✅ **方法2: 手動設定（推奨）**
        1. 設定アプリを開く
        2. プライバシーとセキュリティ
        3. ローカルネットワーク
        4. 「takibi」をオンにする
        5. アプリを再起動
        
        ✅ **方法3: ネットワークリセット**
        1. 設定 > 一般 > 転送またはiPhoneをリセット
        2. リセット > ネットワーク設定をリセット
        3. Wi-Fi再接続後、アプリを再インストール
        
        💡 **確認事項**:
        • Wi-Fi接続されているか
        • VPN接続を無効にする
        • 機内モードをオン→オフして再試行
        • 別のWi-Fiネットワークで試行
        """
        
        DispatchQueue.main.async {
            self.connectionError = message
            self.showingError = true
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
            // 受信したメッセージはisFromMe = falseに設定
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
        // Auto-accept invitations for simplicity
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Advertiser failed to start advertising: \(error.localizedDescription)")
        
        // NSNetServicesエラーをチェック
        if let nsError = error as NSError? {
            let errorCode = nsError.code
            let errorDomain = nsError.domain
            
            print("Advertiser Error domain: \(errorDomain), Error code: \(errorCode)")
            
            // エラーコード -72008 は通常ローカルネットワーク許可の問題
            if errorCode == -72008 {
                DispatchQueue.main.async {
                    self.hasLocalNetworkPermission = false
                    self.showPermissionError()
                    print("Advertising failed due to permission issue - showing error dialog")
                }
            } else {
                DispatchQueue.main.async {
                    self.showConnectionError("デバイスの公開を開始できませんでした。\nエラーコード: \(errorCode)")
                }
            }
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
        print("Browser failed to start browsing: \(error.localizedDescription)")
        
        // NSNetServicesエラーをチェック
        if let nsError = error as NSError? {
            let errorCode = nsError.code
            let errorDomain = nsError.domain
            
            print("Error domain: \(errorDomain), Error code: \(errorCode)")
            
            // エラーコード -72008 は通常ローカルネットワーク許可の問題
            if errorCode == -72008 {
                DispatchQueue.main.async {
                    self.hasLocalNetworkPermission = false
                    self.showConnectionError("ローカルネットワークへのアクセス許可が必要です。\n設定 > プライバシーとセキュリティ > ローカルネットワーク で takibi を有効にしてください。")
                }
                
                // 許可を再要求
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.requestLocalNetworkPermissionIfNeeded()
                }
            } else {
                DispatchQueue.main.async {
                    self.showConnectionError("ネットワーク検索を開始できませんでした。\nエラーコード: \(errorCode)")
                }
            }
        }
    }
}
