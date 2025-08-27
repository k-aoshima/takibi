//
//  ChatMessage.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import Foundation

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let senderID: String
    let timestamp: Date
    var isFromMe: Bool = false
    
    init(content: String, senderID: String, timestamp: Date = Date(), isFromMe: Bool = false) {
        self.content = content
        self.senderID = senderID
        self.timestamp = timestamp
        self.isFromMe = isFromMe
    }
    
    // CodingKeysを定義してidとisFromMeを除外（ローカルでのみ使用）
    private enum CodingKeys: String, CodingKey {
        case content, senderID, timestamp
    }
    
    // デコード時のカスタム初期化
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decode(String.self, forKey: .content)
        self.senderID = try container.decode(String.self, forKey: .senderID)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.isFromMe = false // デフォルトはfalse、受信時に設定
    }
    
    // エンコード時のカスタム処理
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encode(senderID, forKey: .senderID)
        try container.encode(timestamp, forKey: .timestamp)
        // isFromMeはエンコードしない（ローカルでのみ使用）
    }
}
