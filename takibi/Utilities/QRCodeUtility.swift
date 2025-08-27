//
//  QRCodeUtility.swift
//  takibi
//
//  Created by 青嶋広輔 on 8/28/25.
//

import Foundation
import UIKit
import CoreImage

class QRCodeUtility {
    
    static func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            print("❌ Failed to create QR Code filter")
            return nil
        }
        
        filter.setValue(data, forKey: "inputMessage")
        
        // 高い補正レベルを設定
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else {
            print("❌ Failed to generate QR Code output image")
            return nil
        }
        
        // 画像をスケールアップして鮮明にする
        let scaleX = 200 / outputImage.extent.size.width
        let scaleY = 200 / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            print("❌ Failed to create CGImage from QR Code")
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Connection String Methods
    static func createConnectionString(peerID: String, serviceType: String) -> String {
        let connectionInfo = [
            "peerID": peerID,
            "serviceType": serviceType,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: connectionInfo),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ Failed to serialize connection info to JSON")
            return "error://connection-failed"
        }
        
        print("📱 Creating connection string: \(jsonString)")
        return jsonString
    }
    
    static func parseConnectionString(_ string: String) -> (peerID: String, serviceType: String)? {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let peerID = json["peerID"] as? String,
              let serviceType = json["serviceType"] as? String else {
            print("❌ Failed to parse connection string")
            return nil
        }
        
        print("📱 Parsed connection string - PeerID: \(peerID), ServiceType: \(serviceType)")
        return (peerID: peerID, serviceType: serviceType)
    }
    
    static func generateConnectionQRCode(peerID: String, serviceType: String) -> UIImage? {
        let connectionString = createConnectionString(peerID: peerID, serviceType: serviceType)
        return generateQRCode(from: connectionString)
    }
    
    static func parseConnectionQRCode(from string: String) -> (peerID: String, serviceType: String)? {
        return parseConnectionString(string)
    }
    
    static func createStyledQRCode(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard let qrImage = generateQRCode(from: string) else {
            return nil
        }
        
        // 白い背景を作成
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        
        // 白い背景を描画
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // QRコードを中央に描画
        let qrRect = CGRect(
            x: (size.width - 180) / 2,
            y: (size.height - 180) / 2,
            width: 180,
            height: 180
        )
        qrImage.draw(in: qrRect)
        
        let styledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return styledImage
    }
}
