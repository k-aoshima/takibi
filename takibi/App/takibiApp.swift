//
//  takibiApp.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import SwiftUI

@main
struct takibiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // MultipeerConnectivityの設定をここで行う
                    configureMultipeerConnectivity()
                }
        }
    }
    
    private func configureMultipeerConnectivity() {
        // この関数は将来的にMultipeerConnectivityの設定が必要な場合に使用
        print("Multipeer Connectivity configured")
    }
}
