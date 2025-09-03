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
    @State private var showingSaveAlert = false
    @State private var saveError: String?
    @State private var imageSaver: ImageSaver?
    
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
                    // ImageSaverインスタンスを作成
                    let saver = ImageSaver { success, error in
                        if success {
                            self.saveError = nil
                        } else {
                            self.saveError = error?.localizedDescription ?? "画像の保存に失敗しました"
                        }
                        self.showingSaveAlert = true
                    }
                    self.imageSaver = saver
                    // 写真を保存
                    UIImageWriteToSavedPhotosAlbum(image, saver, #selector(ImageSaver.saveCompleted), nil)
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

class ImageSaver: NSObject {
    var completion: (Bool, Error?) -> Void
    
    init(completion: @escaping (Bool, Error?) -> Void) {
        self.completion = completion
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion(error == nil, error)
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
