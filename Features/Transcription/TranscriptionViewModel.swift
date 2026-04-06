import SwiftUI
import AVFoundation

class TranscriptionViewModel: ObservableObject {
    @Published var selectedVideoURL: URL?
    @Published var videoTitle: String = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var subtitleMode: SubtitleMode = .original  // 字幕模式
    @Published var isImporting: Bool = false

    private let taskManager = TranscriptionTaskManager.shared
    private let uploadService = UploadService.shared

    var canTranscribe: Bool {
        selectedVideoURL != nil && !videoTitle.isEmpty
    }

    func selectVideo(url: URL) {
        selectedVideoURL = url
        videoTitle = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    func clearSelection() {
        selectedVideoURL = nil
        videoTitle = ""
        errorMessage = nil
        successMessage = nil
    }

    func startTranscription() {
        guard let videoURL = selectedVideoURL else { return }

        do {
            // 复制视频到文档目录（因为任务在后台执行）
            let videoPath = try uploadService.copyVideoToDocuments(from: videoURL)

            // 开始转录任务
            _ = taskManager.startTranscription(
                videoTitle: videoTitle,
                videoPath: videoPath,
                subtitleMode: subtitleMode
            )

            successMessage = "转录任务已添加，完成后会在通知中提醒"
            clearSelection()

        } catch {
            errorMessage = "添加转录任务失败: \(error.localizedDescription)"
        }
    }

    func importTask(_ task: TranscriptionTask) {
        guard !isImporting else { return }
        isImporting = true

        Task { @MainActor in
            do {
                let thumbnailPath = uploadService.generateThumbnail(for: task.videoPath)
                let duration = uploadService.getVideoDuration(for: task.videoPath)

                var subPath: String?
                if let originalSubtitlePath = task.subtitlePath {
                    subPath = try uploadService.copySubtitleToDocuments(from: URL(fileURLWithPath: originalSubtitlePath))
                }

                let video = Video(
                    title: task.videoTitle,
                    localPath: task.videoPath,
                    thumbnailPath: thumbnailPath,
                    duration: duration,
                    subtitlePath: subPath
                )

                let repository = VideoRepository()
                try repository.save(video)

                isImporting = false
                successMessage = "视频 \"\(task.videoTitle)\" 已导入到视频库"

            } catch {
                isImporting = false
                errorMessage = "导入失败: \(error.localizedDescription)"
            }
        }
    }
}
