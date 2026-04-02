import Foundation
import Speech
import AVFoundation
import WhisperKit

class TranscriptionService {
    static let shared = TranscriptionService()

    private let speechRecognizer: SFSpeechRecognizer?
    private var isOnDeviceRecognitionAvailable = false
    var whisperKit: WhisperKit?

    /// 进度回调类型 (progress: 0.0 - 1.0, phase: String)
    typealias ProgressHandler = (Double, String) -> Void

    // MARK: - Whisper API Configuration

    /// Whisper API URL (can be changed to use a proxy or compatible API)
    var whisperAPIURL: String = "https://api.openai.com/v1/audio/transcriptions"

    /// API Key for Whisper API
    var apiKey: String = ""

    /// 是否使用 Whisper API
    var useWhisperAPI: Bool = false

    /// 是否使用本地 WhisperKit
    var useWhisperKit: Bool = false

    private init() {
        // 使用美式英语语音识别
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        // 检查是否支持设备端识别 (iOS 17+)
        if #available(iOS 17.0, *) {
            isOnDeviceRecognitionAvailable = speechRecognizer?.supportsOnDeviceRecognition == true
        }

        // 加载保存的设置
        apiKey = UserDefaults.standard.string(forKey: "whisperAPIKey") ?? ""
        useWhisperAPI = UserDefaults.standard.bool(forKey: "useWhisperAPI")
        whisperAPIURL = UserDefaults.standard.string(forKey: "whisperAPIURL") ?? "https://api.openai.com/v1/audio/transcriptions"
        useWhisperKit = UserDefaults.standard.bool(forKey: "useWhisperKit")
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

    /// 检查语音识别是否可用
    var isAvailable: Bool {
        speechRecognizer?.isAvailable == true
    }

    /// 是否使用设备端识别 (更快)
    var usesOnDeviceRecognition: Bool {
        isOnDeviceRecognitionAvailable
    }

    /// 请求语音识别权限
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// 从视频文件转录语音
    func transcribeVideo(at videoURL: URL, progressHandler: ProgressHandler? = nil) async throws -> [SubtitleEntry] {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

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

        // 第二阶段：语音识别 (30% - 100%)
        progressHandler?(0.3, "正在识别语音...")

        return try await recognizeSpeech(
            from: audioURL,
            audioDuration: duration,
            progressHandler: { recognitionProgress in
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

    /// 执行语音识别
    private func recognizeSpeech(from audioURL: URL, audioDuration: TimeInterval, progressHandler: ((Double) -> Void)?) async throws -> [SubtitleEntry] {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        // 验证音频文件
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: audioURL.path) else {
            print("音频文件不存在: \(audioURL.path)")
            throw TranscriptionError.exportFailed
        }

        let attributes = try? fileManager.attributesOfItem(atPath: audioURL.path)
        let fileSize = attributes?[.size] as? Int64 ?? 0
        print("音频文件大小: \(fileSize) bytes, 时长: \(audioDuration)s")

        if fileSize < 1000 {
            print("警告: 音频文件太小，可能提取失败")
        }

        // 创建识别请求
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true

        // 启用设备端识别 (iOS 17+) - 更快更私密
        if #available(iOS 17.0, *) {
            if speechRecognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
                print("使用设备端语音识别")
            } else {
                print("设备端识别不可用，使用云端识别")
            }
        }

        request.addsPunctuation = true

        let startTime = Date()
        // 设备端识别通常快 2-4 倍，云端慢约 1-2 倍音视频长度
        let isOnDevice = request.requiresOnDeviceRecognition
        let estimatedRecognitionTime = isOnDevice ? audioDuration * 0.5 : min(audioDuration * 2, 300.0)

        print("开始语音识别，音频时长: \(audioDuration)s，估计需要: \(estimatedRecognitionTime)s")
        print("音频文件路径: \(audioURL.path)")

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                // 防止重复 resume
                if hasResumed { return }

                if let error = error {
                    hasResumed = true
                    print("语音识别错误: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else {
                    print("语音识别返回空结果")
                    return
                }

                // 基于时间估算进度
                let elapsed = Date().timeIntervalSince(startTime)
                var estimatedProgress = min(elapsed / estimatedRecognitionTime, 0.95)

                // 获取完整转录文本
                let transcriptionText = result.bestTranscription.formattedString
                print("语音识别进度: \(Int(estimatedProgress * 100))%, 片段数: \(result.bestTranscription.segments.count), 文本长度: \(transcriptionText.count)")

                if result.isFinal {
                    hasResumed = true
                    estimatedProgress = 1.0
                    let entries = self?.convertToSubtitleEntries(result) ?? []
                    print("语音识别完成，共 \(entries.count) 个片段")
                    print("完整转录文本: \(transcriptionText.prefix(200))")
                    progressHandler?(1.0)
                    continuation.resume(returning: entries)
                } else {
                    // 根据已完成的片段比例调整进度（最高到90%）
                    let segmentCount = result.bestTranscription.segments.count
                    if segmentCount > 0 {
                        let segmentProgress = min(Double(segmentCount) / max(audioDuration * 2, 1), 0.9)
                        estimatedProgress = max(estimatedProgress, segmentProgress * 0.9)
                    }
                    progressHandler?(estimatedProgress)
                }
            }
        }
    }

    /// 将识别结果转换为字幕条目
    private func convertToSubtitleEntries(_ result: SFSpeechRecognitionResult) -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []

        for (index, segment) in result.bestTranscription.segments.enumerated() {
            let entry = SubtitleEntry(
                index: index,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                text: segment.substring,
                translation: nil
            )
            entries.append(entry)
        }

        // 合并相邻片段为更自然的字幕
        return mergeSegments(entries)
    }

    /// 合并相邻片段，生成更自然的字幕
    private func mergeSegments(_ entries: [SubtitleEntry], maxDuration: TimeInterval = 5.0) -> [SubtitleEntry] {
        guard !entries.isEmpty else { return [] }

        var merged: [SubtitleEntry] = []
        var currentEntry = entries[0]

        for i in 1..<entries.count {
            let entry = entries[i]
            let timeSinceLastEnd = entry.startTime - currentEntry.endTime

            // 如果间隔小于0.5秒且总时长不超过限制，则合并
            if timeSinceLastEnd < 0.5 && (entry.endTime - currentEntry.startTime) < maxDuration {
                currentEntry = SubtitleEntry(
                    index: currentEntry.index,
                    startTime: currentEntry.startTime,
                    endTime: entry.endTime,
                    text: currentEntry.text + " " + entry.text,
                    translation: nil
                )
            } else {
                merged.append(currentEntry)
                currentEntry = SubtitleEntry(
                    index: merged.count,
                    startTime: entry.startTime,
                    endTime: entry.endTime,
                    text: entry.text,
                    translation: nil
                )
            }
        }

        merged.append(currentEntry)
        return merged
    }

    // MARK: - Whisper API 转录

    /// 使用 Whisper API 转录音频
    func transcribeWithWhisperAPI(audioURL: URL, progressHandler: ProgressHandler? = nil) async throws -> [SubtitleEntry] {
        guard !apiKey.isEmpty else {
            throw TranscriptionError.apiKeyNotSet
        }

        progressHandler?(0.1, "正在上传音频...")

        // 构建请求
        guard let url = URL(string: whisperAPIURL) else {
            throw TranscriptionError.invalidAPIURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // 创建 multipart/form-data 请求
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // 读取音频文件
        let audioData = try Data(contentsOf: audioURL)
        let audioFileName = audioURL.lastPathComponent

        // 构建请求体
        var body = Data()

        // 添加 model 参数
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // 添加 response_format 参数以获取时间戳
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)

        // 添加 language 参数 (英语)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)

        // 添加音频文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioFileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        progressHandler?(0.2, "正在识别语音...")

        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? [String: Any],
               let message = errorMessage["message"] as? String {
                throw TranscriptionError.apiError(message)
            }
            throw TranscriptionError.apiError("HTTP \(httpResponse.statusCode)")
        }

        progressHandler?(0.9, "正在解析结果...")

        // 解析响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranscriptionError.parseError
        }

        let entries = parseWhisperAPIResponse(json)

        progressHandler?(1.0, "转录完成")
        return entries
    }

    /// 解析 Whisper API 响应
    private func parseWhisperAPIResponse(_ json: [String: Any]) -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []

        guard let segments = json["segments"] as? [[String: Any]] else {
            // 如果没有 segments，只有完整文本，创建一个单一的字幕条目
            if let text = json["text"] as? String {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedText.isEmpty {
                    entries.append(SubtitleEntry(
                        index: 0,
                        startTime: 0,
                        endTime: 0,
                        text: trimmedText,
                        translation: nil
                    ))
                }
            }
            return entries
        }

        for (index, segment) in segments.enumerated() {
            guard let startTime = segment["start"] as? Double,
                  let endTime = segment["end"] as? Double,
                  let text = segment["text"] as? String else {
                continue
            }

            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText.isEmpty { continue }

            entries.append(SubtitleEntry(
                index: index,
                startTime: startTime,
                endTime: endTime,
                text: trimmedText,
                translation: nil
            ))
        }

        return entries
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
            for (index, segment) in result.segments.enumerated() {
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
    case unauthorized
    case apiKeyNotSet
    case invalidAPIURL
    case networkError
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "语音识别服务不可用"
        case .exportFailed:
            return "音频提取失败"
        case .invalidVideo:
            return "无法读取视频时长"
        case .unauthorized:
            return "未授权使用语音识别"
        case .apiKeyNotSet:
            return "Whisper API Key 未设置"
        case .invalidAPIURL:
            return "无效的 API 地址"
        case .networkError:
            return "网络请求失败"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .parseError:
            return "解析响应失败"
        }
    }
}
