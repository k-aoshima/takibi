//
//  MessageRowView.swift
//  takibi
//
//  Created by GitHub Copilot on 9/3/25.
//

import SwiftUI

struct MessageRowView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromMe {
                Spacer()
                messageContent
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            } else {
                // 相手のアイコン表示
                if let senderIconType = message.senderIconType {
                    // プロフィール情報からダミーのUserProfileを作成
                    let dummyProfile = UserProfile(displayName: message.senderDisplayName ?? "ユーザー")
                    let profileWithIcon = UserProfile(displayName: dummyProfile.displayName, iconType: senderIconType)
                    
                    ProfileImageView(profile: profileWithIcon, size: 32)
                } else {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 24))
                        .frame(width: 32, height: 32)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // 送信者名表示
                    if let displayName = message.senderDisplayName {
                        Text(displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    messageContent
                        .background(Color(UIColor.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
    
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 10) {
        MessageRowView(message: ChatMessage(
            content: "こんにちは！",
            senderID: "user1",
            isFromMe: false,
            senderDisplayName: "田中太郎",
            senderProfile: UserProfile(displayName: "田中太郎", iconName: "person.circle.fill", iconColor: .blue)
        ))
        
        MessageRowView(message: ChatMessage(
            content: "よろしくお願いします！",
            senderID: "me",
            isFromMe: true
        ))
    }
    .padding()
}
