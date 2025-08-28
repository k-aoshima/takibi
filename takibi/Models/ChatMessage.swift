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
    let isFromMe: Bool
    
    init(content: String, senderID: String, isFromMe: Bool = false) {
        self.content = content
        self.senderID = senderID
        self.timestamp = Date()
        self.isFromMe = isFromMe
    }
}
