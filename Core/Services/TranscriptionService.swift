import Foundation
import AVFoundation
import WhisperKit

class TranscriptionService {
    static let shared = TranscriptionService()

    var whisperKit: WhisperKit?

    /// 进度回调类型 (progress: 0.0 - 1.0, phase: String)
    typealias ProgressHandler = (Double, String) -> Void

    private init() {
        // 加载保存的设置
        let _ = UserDefaults.standard.bool(forKey: "useWhisperKit")
    }

    // MARK: - WhisperKit

    /// WhisperKit 模型名称 (tiny/base/small/medium/large-v1/large-v2/large-v3)
    var whisperModelName: String = "openai_whisper-tiny"

    /// 本地模型文件夹路径 (nil 则从 bundle 加载)
    var localModelFolder: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("WhisperModels")
    }

    /// 初始化 WhisperKit
    /// - Parameter useLocalModel: 是否使用本地预置模型 (默认 true)
    func initWhisperKit(useLocalModel: Bool = true) async throws {
        let modelFolderPath: String?

        if useLocalModel, let localPath = localModelFolder {
            // 检查本地模型是否存在
            let modelExists = FileManager.default.fileExists(atPath: localPath.path)
            print("本地模型路径: \(localPath.path), 存在: \(modelExists)")

            if modelExists {
                // 查找模型子目录 (如 openai_whisper-tiny)
                if let modelSubDir = findModelSubfolder(in: localPath) {
                    modelFolderPath = modelSubDir.path
                } else {
                    modelFolderPath = localPath.path
                }
            } else {
                modelFolderPath = nil
            }
        } else {
            modelFolderPath = nil
        }

        let config = WhisperKitConfig(
            model: whisperModelName,
            modelFolder: modelFolderPath,
            verbose: true,
            logLevel: .debug,
            download: modelFolderPath == nil  // 本地模型不存在时尝试下载
        )

        whisperKit = try await WhisperKit(config)
    }

    /// 查找模型子文件夹
    private func findModelSubfolder(in baseURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        // 查找包含 mlmodelc 文件的子目录
        for item in contents {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                // 检查是否包含 CoreML 模型
                let melSpec = item.appendingPathComponent("MelSpectrogram.mlmodelc")
                let encoder = item.appendingPathComponent("AudioEncoder.mlmodelc")
                let decoder = item.appendingPathComponent("TextDecoder.mlmodelc")

                if fileManager.fileExists(atPath: melSpec.path) &&
                   fileManager.fileExists(atPath: encoder.path) &&
                   fileManager.fileExists(atPath: decoder.path) {
                    print("找到模型子目录: \(item.lastPathComponent)")
                    return item
                }
            }
        }
        return nil
    }

    /// 从视频文件转录语音 (使用 WhisperKit)
    func transcribeVideo(at videoURL: URL, progressHandler: ProgressHandler? = nil) async throws -> [SubtitleEntry] {
        // 获取视频时长用于计算进度
        let asset = AVAsset(url: videoURL)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite && duration > 0 else {
            throw TranscriptionError.invalidVideo
        }

        // 第一阶段：从视频提取音频 (0% - 30%)
        progressHandler?(0.0, "正在提取音频...")
        let audioURL = try await extractAudio(from: videoURL, progressHandler: { extractProgress in
            progressHandler?(extractProgress * 0.3, "正在提取音频...")
        })

        // 第二阶段：WhisperKit 转录 (30% - 100%)
        progressHandler?(0.3, "正在识别语音...")

        return try await transcribeWithWhisperKit(
            audioURL: audioURL,
            progressHandler: { recognitionProgress, _ in
                let overallProgress = 0.3 + (recognitionProgress * 0.7)
                progressHandler?(overallProgress, "正在识别语音... (\(Int(recognitionProgress * 100))%)")
            }
        )
    }

    /// 提取视频中的音频到临时文件
    private func extractAudio(from videoURL: URL, progressHandler: ((Double) -> Void)?) async throws -> URL {
        print("开始提取音频，视频路径: \(videoURL.path)")

        let asset = AVAsset(url: videoURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            print("无法创建音频导出会话")
            throw TranscriptionError.exportFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        print("音频输出路径: \(outputURL.path)")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // 监听导出进度
        let progressTask = Task {
            while !Task.isCancelled {
                let progress = Double(exportSession.progress)
                progressHandler?(min(progress, 1.0))
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
        }

        await exportSession.export()
        progressTask.cancel()

        if let error = exportSession.error {
            print("音频导出错误: \(error.localizedDescription)")
            throw error
        }

        // 验证输出文件是否存在
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            let attributes = try? fileManager.attributesOfItem(atPath: outputURL.path)
            let fileSize = attributes?[.size] as? Int64 ?? 0
            print("音频提取成功，文件大小: \(fileSize) bytes")
        } else {
            print("音频提取失败：输出文件不存在")
            throw TranscriptionError.exportFailed
        }

        progressHandler?(1.0)
        return outputURL
    }

    // MARK: - SRT 生成

    /// 生成 SRT 格式字幕
    func generateSRT(from entries: [SubtitleEntry]) -> String {
        var srt = ""
        for (index, entry) in entries.enumerated() {
            let startFormatted = formatSRTTime(entry.startTime)
            let endFormatted = formatSRTTime(entry.endTime)

            srt += "\(index + 1)\n"
            srt += "\(startFormatted) --> \(endFormatted)\n"
            srt += "\(entry.text)\n\n"
        }
        return srt
    }

    /// 生成带翻译的 SRT 格式字幕
    func generateTranslatedSRT(from entries: [SubtitleEntry]) -> String {
        var srt = ""
        for (index, entry) in entries.enumerated() {
            let startFormatted = formatSRTTime(entry.startTime)
            let endFormatted = formatSRTTime(entry.endTime)

            srt += "\(index + 1)\n"
            srt += "\(startFormatted) --> \(endFormatted)\n"
            srt += "\(entry.text)\n"
            if let translation = entry.translation {
                srt += "\(translation)\n"
            }
            srt += "\n"
        }
        return srt
    }

    private func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

    // MARK: - WhisperKit 本地转录

    /// 使用 WhisperKit 转录音频
    func transcribeWithWhisperKit(audioURL: URL, progressHandler: ProgressHandler? = nil) async throws -> [SubtitleEntry] {
        // 初始化 WhisperKit（如果尚未初始化）
        if whisperKit == nil {
            progressHandler?(0.1, "正在初始化 WhisperKit...")
            try await initWhisperKit()
        }

        guard let whisperKit = whisperKit else {
            throw TranscriptionError.recognizerUnavailable
        }

        progressHandler?(0.3, "正在转录...")

        // 转录
        let startTime = Date()
        let results: [[TranscriptionResult]?] = try await whisperKit.transcribe(audioPaths: [audioURL.path])

        let transcriptionDuration = Date().timeIntervalSince(startTime)
        print("WhisperKit 转录完成，耗时: \(transcriptionDuration)秒")

        // 转换为字幕条目
        var entries: [SubtitleEntry] = []

        // 处理结果数组 - results[0] 是第一个音频文件的结果
        guard let audioResults = results.first, let transcriptionResults = audioResults else {
            return entries
        }

        // 遍历所有转录结果
        for result in transcriptionResults {
            for (_, segment) in result.segments.enumerated() {
                // 清理时间戳标记 (如 <|21.66|>)
                let cleanedText = cleanWhisperTimestamp(segment.text)
                let entry = SubtitleEntry(
                    index: entries.count,
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end),
                    text: cleanedText,
                    translation: nil
                )
                entries.append(entry)
            }
        }

        progressHandler?(1.0, "转录完成")
        return entries
    }

    /// 清理 Whisper 输出中的所有特殊标记
    /// 如: "<|21.66|>Hello world<|24.30|>" -> "Hello world"
    /// 如: "<|startoftranscript|><|en|><|transcribe|>Hello" -> "Hello"
    func cleanWhisperTimestamp(_ text: String) -> String {
        // Whisper 特殊标记模式
        let specialTokens = [
            "<|startoftranscript|>",
            "<|startodtranscript|>",  // Whisper 有时会拼错
            "<|endoftranscript|>",
            "<|transcribe|>",
            "<|translate|>",
            "<|nospeech|>",
            "<|notimestamps|>",
            "<|en|>",
            "<|zh|>",
            "<|ja|>",
            "<|ko|>",
            "<|fr|>",
            "<|de|>",
            "<|es|>",
            "<|it|>",
            "<|pt|>",
            "<|ru|>",
            "<|ar|>"
        ]

        var cleaned = text

        // 移除所有 Whisper 特殊标记
        for token in specialTokens {
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }

        // 匹配 <|数字.数字|> 格式的时间戳标记
        let timestampPattern = "<\\|\\d+\\.\\d+\\|>"
        if let regex = try? NSRegularExpression(pattern: timestampPattern, options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }

        // 清理多余的空格和换行
        cleaned = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return cleaned
    }
}

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case exportFailed
    case invalidVideo

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "WhisperKit 初始化失败"
        case .exportFailed:
            return "音频提取失败"
        case .invalidVideo:
            return "无法读取视频时长"
        }
    }
}
