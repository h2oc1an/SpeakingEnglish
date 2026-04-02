import SwiftUI
import AVFoundation

class UploadViewModel: ObservableObject {
    @Published var selectedVideoURL: URL?
    @Published var selectedSubtitleURL: URL?
    @Published var videoTitle: String = ""
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isTranslating: Bool = false

    // 翻译进度
    @Published var translateProgress: Double = 0
    @Published var translateStatus: String = ""

    private let uploadService = UploadService.shared
    private let videoService = VideoService.shared
    private let transcriptionService = TranscriptionService.shared
    private let translationService = TranslationService.shared

    var canUpload: Bool {
        selectedVideoURL != nil && !videoTitle.isEmpty && !isUploading
    }

    var canTranslate: Bool {
        selectedSubtitleURL != nil && !isTranslating
    }

    func selectVideo(url: URL) {
        selectedVideoURL = url
        if videoTitle.isEmpty {
            videoTitle = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    func selectSubtitle(url: URL) {
        selectedSubtitleURL = url
    }

    func clearSelection() {
        selectedVideoURL = nil
        selectedSubtitleURL = nil
        videoTitle = ""
        errorMessage = nil
        successMessage = nil
        translateProgress = 0
        translateStatus = ""
    }

    /// 翻译字幕
    @MainActor
    func translateSubtitle() async {
        guard let subtitleURL = selectedSubtitleURL else { return }

        isTranslating = true
        errorMessage = nil
        translateProgress = 0
        translateStatus = "准备翻译..."

        do {
            let parser = SRTSubtitleParser()
            var entries = try parser.parse(fileURL: subtitleURL)

            if entries.isEmpty {
                errorMessage = "字幕文件为空"
                isTranslating = false
                translateStatus = ""
                return
            }

            let totalEntries = entries.count
            print("开始翻译 \(totalEntries) 条字幕")

            for i in 0..<entries.count {
                translateStatus = "翻译中... (\(i + 1)/\(totalEntries))"
                let progress = Double(i) / Double(totalEntries)
                translateProgress = progress

                do {
                    let translation = try await translationService.translate(entries[i].text)
                    entries[i].translation = translation
                } catch {
                    print("翻译第 \(i + 1) 条失败: \(error)")
                    entries[i].translation = "[翻译失败]"
                }
            }

            translateStatus = "正在保存..."
            let srtContent = transcriptionService.generateTranslatedSRT(from: entries)

            let tempDir = FileManager.default.temporaryDirectory
            let translatedFileName = subtitleURL.deletingPathExtension().lastPathComponent + "_cn.srt"
            let tempSubtitleURL = tempDir.appendingPathComponent(translatedFileName)

            try srtContent.write(to: tempSubtitleURL, atomically: true, encoding: String.Encoding.utf8)
            selectedSubtitleURL = tempSubtitleURL

            isTranslating = false
            translateProgress = 1.0
            translateStatus = "翻译完成"

        } catch {
            print("翻译失败: \(error)")
            errorMessage = "翻译失败: \(error.localizedDescription)"
            isTranslating = false
            translateStatus = ""
        }
    }

    func upload(completion: @escaping (Bool) -> Void) {
        guard let videoURL = selectedVideoURL else {
            errorMessage = "请选择视频文件"
            completion(false)
            return
        }

        guard !videoTitle.isEmpty else {
            errorMessage = "请输入视频标题"
            completion(false)
            return
        }

        isUploading = true
        errorMessage = nil
        uploadProgress = 0.1

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                DispatchQueue.main.async { self.uploadProgress = 0.3 }
                let videoPath = try self.uploadService.copyVideoToDocuments(from: videoURL)

                var subtitlePath: String?
                if let subtitleURL = self.selectedSubtitleURL {
                    subtitlePath = try self.uploadService.copySubtitleToDocuments(from: subtitleURL)
                }

                DispatchQueue.main.async { self.uploadProgress = 0.6 }
                let thumbnailPath = self.uploadService.generateThumbnail(for: videoPath)
                let duration = self.uploadService.getVideoDuration(for: videoPath)

                DispatchQueue.main.async { self.uploadProgress = 0.8 }
                let video = Video(
                    title: self.videoTitle,
                    localPath: videoPath,
                    thumbnailPath: thumbnailPath,
                    duration: duration,
                    subtitlePath: subtitlePath
                )

                let repository = VideoRepository()
                try repository.save(video)

                DispatchQueue.main.async {
                    self.uploadProgress = 1.0
                    self.isUploading = false
                    self.successMessage = "上传成功！"
                    self.clearSelection()
                    completion(true)
                }

            } catch {
                DispatchQueue.main.async {
                    self.isUploading = false
                    self.errorMessage = "上传失败: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
}
