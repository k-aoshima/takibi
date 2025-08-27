//
//  ChatMessage.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import Foundation
import UIKit

struct ChatMessage: Codable, Identifiable {
    var id = UUID()
    let content: String
    let senderID: String
    let timestamp: Date
    
    var isFromMe: Bool {
        return senderID == UIDevice.current.name
    }
    
    // CodingKeysを定義してidを除外
    private enum CodingKeys: String, CodingKey {
        case content, senderID, timestamp
    }
}
