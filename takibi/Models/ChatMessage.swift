//
//  ChatMessage.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import Foundation
import SwiftUI

enum MessageType: Codable {
    case text(String)
    case image(Data)
    case imageWithText(imageData: Data, text: String)
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let messageType: MessageType
    let senderID: String
    let timestamp: Date
    let isFromMe: Bool
    let senderProfile: UserProfile
    
    // Codableの実装でidを除外
    enum CodingKeys: String, CodingKey {
        case messageType, senderID, timestamp, isFromMe, senderProfile
    }
    
    // テキストメッセージ用イニシャライザー
    init(text: String, senderID: String, isFromMe: Bool = false, senderProfile: UserProfile) {
        self.messageType = .text(text)
        self.senderID = senderID
        self.timestamp = Date()
        self.isFromMe = isFromMe
        self.senderProfile = senderProfile
    }
    
    // 画像メッセージ用イニシャライザー
    init(imageData: Data, senderID: String, isFromMe: Bool = false, senderProfile: UserProfile) {
        self.messageType = .image(imageData)
        self.senderID = senderID
        self.timestamp = Date()
        self.isFromMe = isFromMe
        self.senderProfile = senderProfile
    }
    
    // 画像とテキストの組み合わせメッセージ用イニシャライザー
    init(imageData: Data, text: String, senderID: String, isFromMe: Bool = false, senderProfile: UserProfile) {
        self.messageType = .imageWithText(imageData: imageData, text: text)
        self.senderID = senderID
        self.timestamp = Date()
        self.isFromMe = isFromMe
        self.senderProfile = senderProfile
    }
    
    // 汎用イニシャライザー（受信メッセージ用）
    init(messageType: MessageType, senderID: String, isFromMe: Bool = false, senderProfile: UserProfile) {
        self.messageType = messageType
        self.senderID = senderID
        self.timestamp = Date()
        self.isFromMe = isFromMe
        self.senderProfile = senderProfile
    }
    
    // 便利なプロパティ
    var isImageMessage: Bool {
        switch messageType {
        case .image, .imageWithText:
            return true
        case .text:
            return false
        }
    }
    
    var text: String? {
        switch messageType {
        case .text(let content):
            return content
        case .imageWithText(_, let text):
            return text
        case .image:
            return nil
        }
    }
    
    var imageData: Data? {
        switch messageType {
        case .image(let data):
            return data
        case .imageWithText(let imageData, _):
            return imageData
        case .text:
            return nil
        }
    }
}
