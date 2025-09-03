//
//  ProfileImageView.swift
//  takibi
//
//  Created by GitHub Copilot on 9/3/25.
//

import SwiftUI

struct ProfileImageView: View {
    let profile: UserProfile
    let size: CGFloat
    
    var body: some View {
        switch profile.iconType {
        case .customImage(let data):
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // データが無効な場合のフォールバック
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: size * 0.8))
                    .frame(width: size, height: size)
            }
        case .systemIcon(let name, let color):
            Image(systemName: name)
                .foregroundColor(color.color)
                .font(.system(size: size * 0.8))
                .frame(width: size, height: size)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileImageView(
            profile: UserProfile(displayName: "テストユーザー", iconName: "person.circle.fill", iconColor: .blue),
            size: 60
        )
        
        ProfileImageView(
            profile: UserProfile(displayName: "テストユーザー", iconName: "star.circle.fill", iconColor: .orange),
            size: 40
        )
    }
    .padding()
}
