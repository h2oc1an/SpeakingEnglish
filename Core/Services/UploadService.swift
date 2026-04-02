import Foundation
import AVFoundation
import UIKit

class UploadService {
    static let shared = UploadService()

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var videosDirectory: URL {
        documentsDirectory.appendingPathComponent("Videos", isDirectory: true)
    }

    private var subtitlesDirectory: URL {
        documentsDirectory.appendingPathComponent("Subtitles", isDirectory: true)
    }

    private init() {
        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: subtitlesDirectory, withIntermediateDirectories: true)
    }

    /// 复制视频文件到 Documents/Videos
    func copyVideoToDocuments(from sourceURL: URL) throws -> String {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = videosDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.path
    }

    /// 复制字幕文件到 Documents/Subtitles
    func copySubtitleToDocuments(from sourceURL: URL) throws -> String {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = subtitlesDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.path
    }

    /// 生成视频缩略图
    func generateThumbnail(for videoPath: String) -> String? {
        let videoURL = URL(fileURLWithPath: videoPath)
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 1, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)

            let thumbnailFileName = UUID().uuidString + ".jpg"
            let thumbnailURL = documentsDirectory.appendingPathComponent(thumbnailFileName)

            if let data = uiImage.jpegData(compressionQuality: 0.8) {
                try data.write(to: thumbnailURL)
                return thumbnailURL.path
            }
        } catch {
            print("Thumbnail generation failed: \(error)")
        }

        return nil
    }

    /// 获取视频时长
    func getVideoDuration(for videoPath: String) -> TimeInterval {
        let videoURL = URL(fileURLWithPath: videoPath)
        let asset = AVAsset(url: videoURL)
        return CMTimeGetSeconds(asset.duration)
    }

    /// 验证视频文件
    func isValidVideo(url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }

    /// 验证字幕文件
    func isValidSubtitle(url: URL) -> Bool {
        let subtitleExtensions = ["srt", "ass", "ssa"]
        return subtitleExtensions.contains(url.pathExtension.lowercased())
    }
}
