//
//  ChatMessage.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let senderID: String
    let timestamp: Date
    let isFromMe: Bool
    
    // ユーザープロフィール情報を追加
    let senderDisplayName: String?
    let senderIconType: ProfileIconType?
    
    init(content: String, senderID: String, isFromMe: Bool = false, senderDisplayName: String? = nil, senderProfile: UserProfile? = nil) {
        self.content = content
        self.senderID = senderID
        self.timestamp = Date()
        self.isFromMe = isFromMe
        self.senderDisplayName = senderDisplayName
        self.senderIconType = senderProfile?.iconType
    }
    
    // 後方互換性のためのプロパティ
    var senderIconName: String? {
        switch senderIconType {
        case .systemIcon(let name, _):
            return name
        case .customImage:
            return "photo.circle.fill"
        case .none:
            return nil
        }
    }
    
    var senderIconColor: CodableColor? {
        switch senderIconType {
        case .systemIcon(_, let color):
            return color
        case .customImage:
            return CodableColor(color: .blue)
        case .none:
            return nil
        }
    }
}
