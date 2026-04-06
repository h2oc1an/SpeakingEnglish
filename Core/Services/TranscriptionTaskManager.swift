import Foundation
import Combine
import UserNotifications
import UIKit
import AVFoundation

/// 转录任务状态
enum TranscriptionTaskStatus: String, Codable {
    case queued = "排队中"
    case inProgress = "转录中"
    case completed = "已完成"
    case failed = "失败"
    case cancelled = "已取消"
}

/// 字幕模式
enum SubtitleMode: String, Codable, CaseIterable {
    case original = "原字幕"      // 只显示原文
    case chinese = "中文字幕"      // 只显示中文
    case bilingual = "双语字幕"     // 同时显示原文和中文

    var displayName: String { rawValue }

    /// 翻译页面可用的模式（排除原字幕）
    static var translationModes: [SubtitleMode] {
        [.chinese, .bilingual]
    }
}

/// 转录任务模型
struct TranscriptionTask: Identifiable, Codable {
    let id: UUID
    var videoTitle: String
    var videoPath: String
    var subtitlePath: String?
    var status: TranscriptionTaskStatus
    var progress: Double
    var statusMessage: String
    var createdAt: Date
    var completedAt: Date?
    var errorMessage: String?
    var entries: [SubtitleEntry]?
    var subtitleMode: SubtitleMode  // 字幕模式

    init(id: UUID = UUID(),
         videoTitle: String,
         videoPath: String,
         subtitlePath: String? = nil,
         status: TranscriptionTaskStatus = .queued,
         progress: Double = 0,
         statusMessage: String = "等待中...",
         createdAt: Date = Date(),
         subtitleMode: SubtitleMode = .original) {
        self.id = id
        self.videoTitle = videoTitle
        self.videoPath = videoPath
        self.subtitlePath = subtitlePath
        self.status = status
        self.progress = progress
        self.statusMessage = statusMessage
        self.createdAt = createdAt
        self.completedAt = nil
        self.errorMessage = nil
        self.entries = nil
        self.subtitleMode = subtitleMode
    }

    /// 是否需要翻译
    var needsTranslation: Bool {
        subtitleMode != .original
    }

    /// 是否需要双语（原文+翻译）
    var needsBilingual: Bool {
        subtitleMode == .bilingual
    }
}

/// 转录任务管理器 (单例)
class TranscriptionTaskManager: ObservableObject {
    static let shared = TranscriptionTaskManager()

    @Published var tasks: [TranscriptionTask] = []

    private var runningTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var notificationCenter = UNUserNotificationCenter.current()

    private init() {
        requestNotificationPermission()
        loadTasks()
    }

    // MARK: - Notification

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知权限已授予")
            }
        }
    }

    private func sendNotification(title: String, body: String, taskID: UUID? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: taskID?.uuidString ?? UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    // MARK: - Task Management

    /// 添加并开始转录任务
    func startTranscription(videoTitle: String, videoPath: String, subtitleMode: SubtitleMode = .original) -> UUID {
        let taskID = addTask(videoTitle: videoTitle, videoPath: videoPath, subtitleMode: subtitleMode)
        executeTask(taskID)
        return taskID
    }

    /// 添加任务到队列
    func addTask(videoTitle: String, videoPath: String, subtitleMode: SubtitleMode = .original) -> UUID {
        let task = TranscriptionTask(
            videoTitle: videoTitle,
            videoPath: videoPath,
            subtitleMode: subtitleMode
        )
        tasks.insert(task, at: 0)
        saveTasks()
        return task.id
    }

    /// 执行任务
    private func executeTask(_ taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        tasks[index].status = .inProgress
        tasks[index].statusMessage = "准备中..."
        saveTasks()

        startBackgroundTask()

        runningTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            let videoURL = URL(fileURLWithPath: self.tasks.first { $0.id == taskID }?.videoPath ?? "")
            let transcriptionService = TranscriptionService.shared

            do {
                // 检查是否被取消
                try Task.checkCancellation()

                // 提取音频
                await MainActor.run {
                    self.updateProgress(taskID, progress: 0.1, message: "正在提取音频...")
                }
                let audioURL = try await transcriptionService.extractAudio(from: videoURL) { progress in
                    let overallProgress = 0.1 + (progress * 0.2)
                    Task { @MainActor in
                        self.updateProgress(taskID, progress: overallProgress, message: "正在提取音频...")
                    }
                }

                // 使用 defer 确保临时文件被清理
                defer {
                    try? FileManager.default.removeItem(at: audioURL)
                }

                try Task.checkCancellation()

                // 初始化 WhisperKit
                await MainActor.run {
                    self.updateProgress(taskID, progress: 0.2, message: "正在初始化 WhisperKit...")
                }
                if transcriptionService.whisperKit == nil {
                    try await transcriptionService.initWhisperKit()
                }

                try Task.checkCancellation()

                // 转录
                await MainActor.run {
                    self.updateProgress(taskID, progress: 0.3, message: "正在转录...")
                }
                var entries = try await transcriptionService.transcribeWithWhisperKit(audioURL: audioURL) { [weak self] progress, status in
                    Task { @MainActor in
                        let overallProgress = 0.3 + (progress * 0.6)
                        self?.updateProgress(taskID, progress: overallProgress, message: status)
                    }
                }

                // 检查是否需要翻译
                let subtitleMode = self.tasks.first { $0.id == taskID }?.subtitleMode ?? .original
                if subtitleMode != .original {
                    try Task.checkCancellation()

                    // 翻译为中文
                    await MainActor.run {
                        self.updateProgress(taskID, progress: 0.9, message: "正在翻译为中文...")
                    }

                    let translationService = TranslationService.shared
                    for i in 0..<entries.count {
                        try Task.checkCancellation()
                        let originalText = entries[i].text
                        if !originalText.isEmpty {
                            do {
                                let translation = try await translationService.translate(originalText)
                                entries[i].translation = translation
                            } catch {
                                print("翻译失败: \(error)")
                                entries[i].translation = ""
                            }
                        }
                    }

                    // 如果是"只显示中文"模式，将翻译内容替换原文
                    if subtitleMode == .chinese {
                        for i in 0..<entries.count {
                            if let translation = entries[i].translation, !translation.isEmpty {
                                entries[i].text = translation
                                entries[i].translation = nil
                            }
                        }
                    }
                }

                try Task.checkCancellation()

                // 生成字幕文件
                await MainActor.run {
                    self.updateProgress(taskID, progress: 0.95, message: "正在保存字幕...")
                }
                let srtContent: String
                if subtitleMode == .bilingual {
                    srtContent = transcriptionService.generateTranslatedSRT(from: entries)
                } else {
                    srtContent = transcriptionService.generateSRT(from: entries)
                }

                let tempDir = FileManager.default.temporaryDirectory
                let videoTitle = self.tasks.first { $0.id == taskID }?.videoTitle ?? "transcript"
                let subtitleFileName = videoTitle.replacingOccurrences(of: " ", with: "_") + ".srt"
                let subtitleURL = tempDir.appendingPathComponent(subtitleFileName)

                try srtContent.write(to: subtitleURL, atomically: true, encoding: .utf8)

                // 完成任务
                await MainActor.run {
                    self.completeTask(taskID, entries: entries, subtitlePath: subtitleURL.path)
                }

            } catch is CancellationError {
                await MainActor.run {
                    self.cancelTask(taskID)
                }
            } catch {
                await MainActor.run {
                    self.failTask(taskID, error: error.localizedDescription)
                }
            }
        }
    }

    /// 更新任务进度
    func updateProgress(_ taskID: UUID, progress: Double, message: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].progress = progress
        tasks[index].statusMessage = message
        saveTasks()
    }

    /// 完成任务
    func completeTask(_ taskID: UUID, entries: [SubtitleEntry], subtitlePath: String?) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        tasks[index].status = .completed
        tasks[index].progress = 1.0
        tasks[index].statusMessage = "转录完成"
        tasks[index].completedAt = Date()
        tasks[index].entries = entries
        tasks[index].subtitlePath = subtitlePath

        saveTasks()

        sendNotification(
            title: "转录完成",
            body: "\"\(tasks[index].videoTitle)\" 字幕已生成",
            taskID: taskID
        )

        endBackgroundTask()
    }

    /// 任务失败
    func failTask(_ taskID: UUID, error: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        tasks[index].status = .failed
        tasks[index].statusMessage = "转录失败"
        tasks[index].errorMessage = error
        tasks[index].completedAt = Date()

        saveTasks()

        sendNotification(
            title: "转录失败",
            body: "\"\(tasks[index].videoTitle)\": \(error)",
            taskID: taskID
        )

        endBackgroundTask()
    }

    /// 取消任务
    func cancelTask(_ taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        runningTask?.cancel()
        runningTask = nil

        tasks[index].status = .cancelled
        tasks[index].completedAt = Date()
        tasks[index].statusMessage = "已取消"

        saveTasks()
        endBackgroundTask()
    }

    /// 删除任务
    func deleteTask(_ taskID: UUID) {
        // 如果是正在执行的任务，先取消
        if let index = tasks.firstIndex(where: { $0.id == taskID }),
           tasks[index].status == .inProgress {
            runningTask?.cancel()
            runningTask = nil
            endBackgroundTask()
        }

        tasks.removeAll { $0.id == taskID }
        saveTasks()
    }

    /// 清空所有任务
    func clearAllTasks() {
        runningTask?.cancel()
        runningTask = nil
        tasks.removeAll()
        saveTasks()
        endBackgroundTask()
    }

    /// 清空已完成/失败的任务
    func clearFinishedTasks() {
        tasks.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
        saveTasks()
    }

    // MARK: - Background Task

    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - Persistence

    private var tasksFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("transcription_tasks.json")
    }

    func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: tasksFileURL)
        } catch {
            print("保存任务失败: \(error)")
        }
    }

    func loadTasks() {
        guard FileManager.default.fileExists(atPath: tasksFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: tasksFileURL)
            tasks = try JSONDecoder().decode([TranscriptionTask].self, from: data)
        } catch {
            print("加载任务失败: \(error)")
        }
    }
}
