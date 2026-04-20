import Foundation
import AVFoundation
import UIKit

class UploadService {
    static let shared = UploadService()

    private let fileManager = FileManager.default
    private let thumbnailService = ThumbnailService.shared

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

    /// 生成视频缩略图 (使用共享的 ThumbnailService)
    func generateThumbnail(for videoPath: String) -> String? {
        return thumbnailService.generateThumbnailSync(
            for: videoPath,
            saveToDirectory: documentsDirectory
        )
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
