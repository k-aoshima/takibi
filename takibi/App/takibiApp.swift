//
//  takibiApp.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import SwiftUI

@main
struct takibiApp: App {
    @StateObject private var multipeerManager = MultipeerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(multipeerManager)
                .onAppear {
                    // アプリ起動時に即座に権限要求を実行
                    configureMultipeerConnectivity()
                }
        }
    }
    
    private func configureMultipeerConnectivity() {
        print("🚀 App launched - Configuring Multipeer Connectivity")
        print("📱 Device: \(UIDevice.current.name)")
        print("🔧 iOS: \(UIDevice.current.systemVersion)")
        
        // 1. アプリ起動直後に権限要求
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("⚡ Requesting permission immediately after app launch")
            multipeerManager.requestLocalNetworkPermissionIfNeeded()
        }
        
        // 2. 権限状態をデバッグ出力
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🔍 Checking permission status after 2 seconds...")
            multipeerManager.recheckPermission()
        }
    }
}
