//
//  MessageRowView.swift
//  takibi
//
//  Created by GitHub Copilot on 9/3/25.
//

import SwiftUI
import Photos

struct MessageRowView: View {
    let message: ChatMessage
        @State private var showingImageFullScreen = false
    @State private var showingSaveAlert = false
    @State private var saveError: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromMe {
                Spacer()
                messageContent
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            } else {
                // 相手のプロフィール画像表示
                ProfileImageView(profile: message.senderProfile, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    // 送信者名表示
                    Text(message.senderProfile.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
        .alert("画像保存", isPresented: $showingSaveAlert) {
            Button("OK") {
                saveError = nil
            }
        } message: {
            if let error = saveError {
                Text(error)
            } else {
                Text("画像が写真ライブラリに保存されました。")
            }
        }
        .sheet(isPresented: $showingImageFullScreen) {
            if let imageData = message.imageData, let image = UIImage(data: imageData) {
                FullScreenImageView(image: image)
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let imageData = message.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .cornerRadius(8)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .onTapGesture {
                        showingImageFullScreen = true
                    }
                    .contextMenu {
                        Button(action: {
                            saveImageToPhotos(image: image)
                        }) {
                            Label("写真に保存", systemImage: "square.and.arrow.down")
                        }
                    }
            }
            
            if let text = message.text {
                Text(text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            
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
    
    private func saveImageToPhotos(image: UIImage) {
        // 写真ライブラリへのアクセス許可を確認
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    // PHPhotoLibraryを使用して画像を保存
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCreationRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.saveError = nil
                            } else {
                                self.saveError = error?.localizedDescription ?? "画像の保存に失敗しました"
                            }
                            self.showingSaveAlert = true
                        }
                    }
                case .denied, .restricted:
                    self.saveError = "写真ライブラリへのアクセスが拒否されています。設定から許可してください。"
                    self.showingSaveAlert = true
                case .notDetermined:
                    self.saveError = "写真ライブラリへのアクセス許可が必要です。"
                    self.showingSaveAlert = true
                @unknown default:
                    self.saveError = "不明なエラーが発生しました。"
                    self.showingSaveAlert = true
                }
            }
        }
    }
}
#Preview {
    VStack(spacing: 10) {
        MessageRowView(message: ChatMessage(
            text: "こんにちは！",
            senderID: "user1",
            isFromMe: false,
            senderProfile: UserProfile(displayName: "田中太郎", iconName: "person.circle.fill", iconColor: .blue)
        ))
        
        MessageRowView(message: ChatMessage(
            text: "よろしくお願いします！",
            senderID: "me",
            isFromMe: true,
            senderProfile: UserProfile(displayName: "私", iconName: "person.circle.fill", iconColor: .green)
        ))
    }
    .padding()
}

struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingSaveAlert = false
    @State private var saveError: String?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                        .offset(offset)
                        .scaleEffect(scale)
                        .onTapGesture(count: 2) {
                            // ダブルタップでズーム切り替え
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                lastScale = 1.0
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveImageToPhotos(image: image)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(Color.black.opacity(0.5), for: .navigationBar)
        }
        .alert("画像保存", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveError ?? "画像が写真ライブラリに保存されました")
        }
    }
    
    private func saveImageToPhotos(image: UIImage) {
        // 写真ライブラリへのアクセス許可を確認
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    // PHPhotoLibraryを使用して画像を保存
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCreationRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.saveError = nil
                            } else {
                                self.saveError = error?.localizedDescription ?? "画像の保存に失敗しました"
                            }
                            self.showingSaveAlert = true
                        }
                    }
                case .denied, .restricted:
                    self.saveError = "写真ライブラリへのアクセスが拒否されています。設定から許可してください。"
                    self.showingSaveAlert = true
                case .notDetermined:
                    self.saveError = "写真ライブラリへのアクセス許可が必要です。"
                    self.showingSaveAlert = true
                @unknown default:
                    self.saveError = "不明なエラーが発生しました。"
                    self.showingSaveAlert = true
                }
            }
        }
    }
}
