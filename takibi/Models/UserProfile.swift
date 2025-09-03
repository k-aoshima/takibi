//
//  UserProfile.swift
//  takibi
//
//  Created by GitHub Copilot on 9/3/25.
//

import Foundation
import SwiftUI

enum ProfileIconType: Codable {
    case systemIcon(name: String, color: CodableColor)
    case customImage(data: Data)
}

struct UserProfile: Codable {
    var displayName: String
    var iconType: ProfileIconType
    var bio: String?
    var location: String?
    var birthdate: Date?
    
    // 後方互換性のための計算プロパティ
    var iconName: String {
        switch iconType {
        case .systemIcon(let name, _):
            return name
        case .customImage:
            return "photo.circle.fill"
        }
    }
    
    var iconColor: CodableColor {
        switch iconType {
        case .systemIcon(_, let color):
            return color
        case .customImage:
            return CodableColor(color: .blue)
        }
    }
    
    init(displayName: String = "ユーザー", iconName: String = "person.circle.fill", iconColor: Color = .blue, bio: String? = nil, location: String? = nil, birthdate: Date? = nil) {
        self.displayName = displayName
        self.iconType = .systemIcon(name: iconName, color: CodableColor(color: iconColor))
        self.bio = bio
        self.location = location
        self.birthdate = birthdate
    }
    
    init(displayName: String, customImageData: Data, bio: String? = nil, location: String? = nil, birthdate: Date? = nil) {
        self.displayName = displayName
        self.iconType = .customImage(data: customImageData)
        self.bio = bio
        self.location = location
        self.birthdate = birthdate
    }
    
    init(displayName: String, iconType: ProfileIconType, bio: String? = nil, location: String? = nil, birthdate: Date? = nil) {
        self.displayName = displayName
        self.iconType = iconType
        self.bio = bio
        self.location = location
        self.birthdate = birthdate
    }
}

// Colorをエンコード/デコード可能にするためのヘルパー構造体
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(color: Color) {
        if let components = UIColor(color).cgColor.components {
            self.red = Double(components[0])
            self.green = Double(components[1])
            self.blue = Double(components[2])
            self.alpha = Double(components[3])
        } else {
            self.red = 0
            self.green = 0
            self.blue = 1
            self.alpha = 1
        }
    }
    
    var color: Color {
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
