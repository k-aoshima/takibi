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
        }
    }
}
