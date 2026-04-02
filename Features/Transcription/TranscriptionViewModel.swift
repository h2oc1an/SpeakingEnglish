import SwiftUI
import AVFoundation

class TranscriptionViewModel: ObservableObject {
    @Published var selectedVideoURL: URL?
    @Published var videoTitle: String = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?

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
            _ = taskManager.startTranscription(videoTitle: videoTitle, videoPath: videoPath)

            successMessage = "转录任务已添加，完成后会在通知中提醒"
            clearSelection()

        } catch {
            errorMessage = "添加转录任务失败: \(error.localizedDescription)"
        }
    }
}
