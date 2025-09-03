//
//  UserProfileManager.swift
//  takibi
//
//  Created by GitHub Copilot on 9/3/25.
//

import Foundation
import SwiftUI

class UserProfileManager: ObservableObject {
    @Published var currentProfile: UserProfile
    
    private let userDefaults = UserDefaults.standard
    private let profileKey = "userProfile"
    
    init() {
        // 保存されたプロファイルを読み込み、なければデフォルトを使用
        if let data = userDefaults.data(forKey: profileKey),
           let savedProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentProfile = savedProfile
        } else {
            self.currentProfile = UserProfile()
        }
    }
    
    func updateProfile(_ profile: UserProfile) {
        self.currentProfile = profile
        saveProfile()
    }
    
    func updateDisplayName(_ name: String) {
        currentProfile = UserProfile(
            displayName: name,
            iconName: currentProfile.iconName,
            iconColor: currentProfile.iconColor.color,
            bio: currentProfile.bio,
            location: currentProfile.location,
            birthdate: currentProfile.birthdate
        )
        saveProfile()
    }
    
    func updateCustomImage(_ imageData: Data) {
        currentProfile = UserProfile(
            displayName: currentProfile.displayName,
            customImageData: imageData,
            bio: currentProfile.bio,
            location: currentProfile.location,
            birthdate: currentProfile.birthdate
        )
        saveProfile()
    }
    
    private func saveProfile() {
        if let data = try? JSONEncoder().encode(currentProfile) {
            userDefaults.set(data, forKey: profileKey)
        }
    }
    
    // ピア表示名を生成（MultipeerConnectivity用）
    func getPeerDisplayName() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let deviceIdentifier: String
        
        #if targetEnvironment(simulator)
        deviceIdentifier = "Simulator"
        #else
        deviceIdentifier = "Device"
        #endif
        
        return "\(currentProfile.displayName)-\(deviceIdentifier)-\(timestamp)"
    }
    
    // ディスカバリー用のプロフィールデータを生成
    func getProfileForDiscovery() -> [String: Any] {
        var profileData: [String: Any] = [
            "nickname": currentProfile.displayName,
            "avatarEmoji": currentProfile.iconName,
            "statusMessage": currentProfile.bio ?? ""
        ]
        
        // 場所と生年月日も追加（オプション）
        if let location = currentProfile.location {
            profileData["location"] = location
        }
        if let birthdate = currentProfile.birthdate {
            profileData["birthdate"] = ISO8601DateFormatter().string(from: birthdate)
        }
        
        return profileData
    }
}
