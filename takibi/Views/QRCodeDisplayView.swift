//
//  QRCodeDisplayView.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/27/25.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeDisplayView: View {
    @EnvironmentObject var multipeerManager: MultipeerManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Share Your QR Code")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("他のデバイスがこのQRコードをスキャンして接続できます")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // QRコード画像
                if let qrImage = generateQRCode(from: multipeerManager.getConnectionQRCode()) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 250, height: 250)
                        .cornerRadius(20)
                        .overlay {
                            Text("QRコード生成エラー")
                                .foregroundColor(.secondary)
                        }
                }
                
                VStack(spacing: 10) {
                    Text("デバイス名: \(UIDevice.current.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("このQRコードは接続用の情報を含んでいます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // QRコード表示時にホスティングを開始
            print("📡 QR Code displayed, starting hosting...")
            multipeerManager.startHosting()
        }
        .onDisappear {
            // QRコード画面を閉じる時はホスティングを停止
            print("📡 QR Code view dismissed, stopping hosting...")
            multipeerManager.stopHosting()
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            let scaleX = 250 / outputImage.extent.size.width
            let scaleY = 250 / outputImage.extent.size.height
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}

#Preview {
    QRCodeDisplayView()
        .environmentObject(MultipeerManager())
}
