//
//  UserSettingsView.swift
//  takibi
//
//  Created by GitHub Copilot on 9/3/25.
//

import SwiftUI
import PhotosUI

struct UserSettingsView: View {
    @ObservedObject var profileManager: UserProfileManager
    @State private var displayName: String
    @State private var selectedCustomImage: UIImage?
    @State private var isShowingPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    
    init(profileManager: UserProfileManager) {
        self.profileManager = profileManager
        self._displayName = State(initialValue: profileManager.currentProfile.displayName)
        
        switch profileManager.currentProfile.iconType {
        case .customImage(let data):
            self._selectedCustomImage = State(initialValue: UIImage(data: data))
        case .systemIcon:
            self._selectedCustomImage = State(initialValue: nil)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // プレビューセクション
                VStack(spacing: 15) {
                    Text("プレビュー")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 10) {
                        if let customImage = selectedCustomImage {
                            Image(uiImage: customImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 60))
                        }
                        
                        Text(displayName.isEmpty ? "ユーザー" : displayName)
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(15)
                }
                
                // 名前設定セクション
                VStack(alignment: .leading, spacing: 10) {
                    Text("表示名")
                        .font(.headline)
                    
                    TextField("名前を入力してください", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                
                // プロフィール写真選択セクション
                VStack(alignment: .leading, spacing: 15) {
                    Text("プロフィール写真")
                        .font(.headline)
                    
                    Button(action: {
                        isShowingPhotoPicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            Text(selectedCustomImage == nil ? "写真を選択" : "写真を変更")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    if selectedCustomImage != nil {
                        Button(action: {
                            selectedCustomImage = nil
                        }) {
                            HStack {
                                Image(systemName: "trash.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 20))
                                Text("写真を削除")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("プロフィール設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let newProfile: UserProfile
                        
                        if let customImage = selectedCustomImage,
                           let imageData = customImage.jpegData(compressionQuality: 0.8) {
                            newProfile = UserProfile(
                                displayName: displayName.isEmpty ? "ユーザー" : displayName,
                                customImageData: imageData
                            )
                        } else {
                            // カスタム画像がない場合はデフォルトの人アイコンを使用
                            newProfile = UserProfile(
                                displayName: displayName.isEmpty ? "ユーザー" : displayName,
                                iconName: "person.circle.fill",
                                iconColor: .blue
                            )
                        }
                        
                        profileManager.updateProfile(newProfile)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedCustomImage = image
                }
            }
        }
    }
}

#Preview {
    UserSettingsView(profileManager: UserProfileManager())
}
