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
    
    // アプリ起動時の初期化処理
    init() {
        // シミュレーター環境での問題を軽減
        setupSimulatorOptimizations()
        // キーボード関連のエラーを軽減
        suppressKeyboardDebugMessages()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(multipeerManager)
                // キーボード入力エラーを防ぐための全体的な設定
                .onAppear {
                    // UIKitレベルでのキーボード設定を初期化
                    setupKeyboardConfiguration()
                }
                // アプリライフサイクルの監視
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    print("🌟 App became active")
                    setupKeyboardConfiguration()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    print("💤 App will resign active")
                }
        }
    }
    
    // キーボード設定の初期化
    private func setupKeyboardConfiguration() {
        // メインスレッドで実行
        DispatchQueue.main.async {
            // UIApplication設定でキーボード関連の問題を回避
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first {
                
                // キーボードの自動修正とスペルチェックを適切に設定
                window.rootViewController?.view.isUserInteractionEnabled = true
                
                // デバッグ情報の出力を抑制
                UserDefaults.standard.set(false, forKey: "UITextInputContextIdentifierUserDefaults")
            }
        }
    }
    
    // シミュレーター環境での最適化
    private func setupSimulatorOptimizations() {
        #if targetEnvironment(simulator)
        // シミュレーター特有の問題を軽減する設定
        UserDefaults.standard.set(false, forKey: "eligibility_daemon_enabled")
        UserDefaults.standard.set(false, forKey: "eligibility_logging_enabled")
        #endif
    }
    
    // キーボードデバッグメッセージの抑制
    private func suppressKeyboardDebugMessages() {
        // テキスト入力システムのデバッグ出力を抑制
        UserDefaults.standard.set(false, forKey: "RTIInputSystemClientDebugEnabled")
        UserDefaults.standard.set(false, forKey: "UIEmojiSearchDebugEnabled")
        UserDefaults.standard.set(0, forKey: "UITextInputDebugLevel")
    }
}
