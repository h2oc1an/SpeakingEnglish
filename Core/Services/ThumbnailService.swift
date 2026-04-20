import Foundation
import AVFoundation
import UIKit

/// 缩略图生成服务 - 统一管理视频缩略图生成逻辑
class ThumbnailService {
    static let shared = ThumbnailService()

    // 内存缓存 (线程安全)
    private let memoryCache = NSCache<NSString, UIImage>()

    private init() {
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    /// 生成视频缩略图
    /// - Parameters:
    ///   - videoURL: 视频URL
    ///   - saveToDirectory: 可选，保存到的目录 (nil 则只返回 UIImage)
    /// - Returns: 缩略图保存路径或 nil
    func generateThumbnail(
        for videoURL: URL,
        saveToDirectory: URL? = nil
    ) async -> String? {
        let cacheKey = videoURL.path as NSString

        // 检查内存缓存
        if let cached = memoryCache.object(forKey: cacheKey) {
            // 如果需要保存到目录
            if let directory = saveToDirectory {
                return saveImage(cached, to: directory)
            }
            return nil
        }

        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 640, height: 360)

        let time = CMTime(seconds: 1, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)

            // 存入内存缓存
            memoryCache.setObject(uiImage, forKey: cacheKey)

            // 如果需要保存到目录
            if let directory = saveToDirectory {
                return saveImage(uiImage, to: directory)
            }
            return nil
        } catch {
            print("Thumbnail generation failed: \(error)")
            return nil
        }
    }

    /// 同步生成缩略图 (用于已有视频URL的情况)
    func generateThumbnailSync(for videoPath: String, saveToDirectory: URL? = nil) -> String? {
        let videoURL = URL(fileURLWithPath: videoPath)
        let cacheKey = videoPath as NSString

        // 检查内存缓存
        if let cached = memoryCache.object(forKey: cacheKey) {
            if let directory = saveToDirectory {
                return saveImage(cached, to: directory)
            }
            return nil
        }

        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 640, height: 360)

        let time = CMTime(seconds: 1, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)

            // 存入内存缓存
            memoryCache.setObject(uiImage, forKey: cacheKey)

            if let directory = saveToDirectory {
                return saveImage(uiImage, to: directory)
            }
            return nil
        } catch {
            print("Thumbnail generation failed: \(error)")
            return nil
        }
    }

    /// 保存图片到指定目录
    private func saveImage(_ image: UIImage, to directory: URL) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = directory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Failed to save thumbnail: \(error)")
            return nil
        }
    }

    /// 清除缓存
    func clearCache() {
        memoryCache.removeAllObjects()
    }
}