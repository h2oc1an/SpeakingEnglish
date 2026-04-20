import Foundation
import AVFoundation
import UIKit

class VideoService {
    static let shared = VideoService()

    private let videoRepository: VideoRepository
    private let thumbnailService = ThumbnailService.shared

    private init() {
        self.videoRepository = VideoRepository()
    }

    func loadSampleVideos() throws {
        // Check if sample videos already loaded
        let existingVideos = try videoRepository.getAll()
        if !existingVideos.isEmpty { return }

        // Get the directory containing the videos
        guard let resourcesURL = Bundle.main.resourceURL else { return }
        let videosDirectory = resourcesURL.appendingPathComponent("SampleVideos")

        // Get all mp4 files in the directory
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: nil) else { return }

        let videoFiles = files.filter { $0.pathExtension.lowercased() == "mp4" }

        for videoURL in videoFiles {
            let videoName = videoURL.deletingPathExtension().lastPathComponent

            let asset = AVAsset(url: videoURL)
            let duration = CMTimeGetSeconds(asset.duration)

            // Generate thumbnail using shared service
            let thumbnailPath = thumbnailService.generateThumbnailSync(
                for: videoURL.path,
                saveToDirectory: FileManager.default.temporaryDirectory
            )

            // Find matching subtitle file (same name, different extension)
            let subtitlePath = findSubtitlePath(for: videoName, in: videosDirectory)

            let video = Video(
                title: videoName.replacingOccurrences(of: "_", with: " ").capitalized,
                localPath: videoURL.path,
                thumbnailPath: thumbnailPath,
                duration: duration,
                subtitlePath: subtitlePath
            )

            try videoRepository.save(video)
        }
    }

    private func findSubtitlePath(for videoName: String, in directory: URL) -> String? {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }

        // Look for SRT or ASS with same name
        for file in files {
            let fileNameWithoutExtension = file.deletingPathExtension().lastPathComponent
            if fileNameWithoutExtension == videoName {
                let ext = file.pathExtension.lowercased()
                if ext == "srt" || ext == "ass" {
                    return file.path
                }
            }
        }
        return nil
    }

    func getAllVideos() throws -> [Video] {
        return try videoRepository.getAll()
    }

    func getVideo(byId id: UUID) throws -> Video? {
        return try videoRepository.getById(id)
    }

    func updateLastPlayed(at date: Date, for videoId: UUID) throws {
        guard var video = try videoRepository.getById(videoId) else { return }
        video.lastPlayedAt = date
        try videoRepository.update(video)
    }

    func deleteVideo(_ video: Video) throws {
        let fileManager = FileManager.default

        // 删除视频文件
        if fileManager.fileExists(atPath: video.localPath) {
            try fileManager.removeItem(atPath: video.localPath)
        }

        // 删除缩略图
        if let thumbnailPath = video.thumbnailPath,
           fileManager.fileExists(atPath: thumbnailPath) {
            try fileManager.removeItem(atPath: thumbnailPath)
        }

        // 删除字幕文件
        if let subtitlePath = video.subtitlePath,
           fileManager.fileExists(atPath: subtitlePath) {
            try fileManager.removeItem(atPath: subtitlePath)
        }

        // 从数据库删除
        try videoRepository.delete(video.id)
    }
}
