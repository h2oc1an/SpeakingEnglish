import Foundation
import Combine
import UserNotifications
import UIKit

/// 翻译任务状态
enum TranslationTaskStatus: String, Codable {
    case queued = "排队中"
    case inProgress = "翻译中"
    case completed = "已完成"
    case failed = "失败"
    case cancelled = "已取消"
}

/// 翻译任务模型
struct TranslationTask: Identifiable, Codable, Hashable {
    let id: UUID
    var sourcePath: String
    var resultPath: String?
    var status: TranslationTaskStatus
    var progress: Double
    var statusMessage: String
    var createdAt: Date
    var completedAt: Date?
    var errorMessage: String?
    var entryCount: Int

    init(
        id: UUID = UUID(),
        sourcePath: String,
        resultPath: String? = nil,
        status: TranslationTaskStatus = .queued,
        progress: Double = 0,
        statusMessage: String = "等待中...",
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        errorMessage: String? = nil,
        entryCount: Int = 0
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.resultPath = resultPath
        self.status = status
        self.progress = progress
        self.statusMessage = statusMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.errorMessage = errorMessage
        self.entryCount = entryCount
    }
}

/// 翻译任务管理器 (单例)
class TranslationTaskManager: ObservableObject {
    static let shared = TranslationTaskManager()

    @Published var tasks: [TranslationTask] = []

    private var runningTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var notificationCenter = UNUserNotificationCenter.current()

    private let translationService = TranslationService.shared
    private let transcriptionService = TranscriptionService.shared

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

    /// 添加并开始翻译任务
    func startTranslation(sourcePath: String, entryCount: Int) -> UUID {
        let taskID = addTask(sourcePath: sourcePath, entryCount: entryCount)
        executeTask(taskID)
        return taskID
    }

    /// 添加任务到队列
    func addTask(sourcePath: String, entryCount: Int) -> UUID {
        let task = TranslationTask(
            sourcePath: sourcePath,
            entryCount: entryCount
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

        runningTask = Task { [weak self] in
            guard let self = self else { return }

            let sourcePath = self.tasks.first { $0.id == taskID }?.sourcePath ?? ""

            do {
                try Task.checkCancellation()

                // 解析字幕文件
                await self.updateProgress(taskID, progress: 0.05, message: "正在解析字幕...")

                let sourceURL = URL(fileURLWithPath: sourcePath)
                let parser = SRTSubtitleParser()
                var entries = try parser.parse(fileURL: sourceURL)

                try Task.checkCancellation()

                if entries.isEmpty {
                    throw TranslationTaskError.emptySubtitle
                }

                // 翻译每一条
                let totalEntries = entries.count
                for i in 0..<entries.count {
                    let progress = 0.1 + (Double(i) / Double(totalEntries)) * 0.8
                    await self.updateProgress(taskID, progress: progress, message: "翻译中... (\(i + 1)/\(totalEntries))")

                    try Task.checkCancellation()

                    do {
                        let translation = try await self.translationService.translate(entries[i].text)
                        entries[i].translation = translation
                    } catch {
                        print("翻译第 \(i + 1) 条失败: \(error)")
                        entries[i].translation = "[翻译失败]"
                    }
                }

                // 生成翻译后的字幕文件
                await self.updateProgress(taskID, progress: 0.95, message: "正在保存...")

                try Task.checkCancellation()

                let srtContent = self.transcriptionService.generateTranslatedSRT(from: entries)
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = sourceURL.deletingPathExtension().lastPathComponent + "_cn.srt"
                let resultURL = tempDir.appendingPathComponent(fileName)

                try srtContent.write(to: resultURL, atomically: true, encoding: .utf8)

                // 完成任务
                await self.completeTask(taskID, resultPath: resultURL.path)

            } catch is CancellationError {
                await self.cancelTaskUI(taskID)
            } catch {
                await self.failTaskUI(taskID, error: error.localizedDescription)
            }
        }
    }

    /// 更新任务进度 (MainActor)
    @MainActor
    private func updateProgress(_ taskID: UUID, progress: Double, message: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].progress = progress
        tasks[index].statusMessage = message
        saveTasks()
    }

    /// 完成任务 (MainActor)
    @MainActor
    private func completeTask(_ taskID: UUID, resultPath: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        let task = tasks[index]

        tasks[index].status = .completed
        tasks[index].progress = 1.0
        tasks[index].statusMessage = "翻译完成"
        tasks[index].completedAt = Date()
        tasks[index].resultPath = resultPath

        saveTasks()

        sendNotification(
            title: "翻译完成",
            body: "字幕翻译已完成，可导入视频",
            taskID: taskID
        )

        endBackgroundTask()
    }

    /// 任务失败 (MainActor)
    @MainActor
    private func failTaskUI(_ taskID: UUID, error: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        tasks[index].status = .failed
        tasks[index].statusMessage = "翻译失败"
        tasks[index].errorMessage = error
        tasks[index].completedAt = Date()

        saveTasks()

        sendNotification(
            title: "翻译失败",
            body: error,
            taskID: taskID
        )

        endBackgroundTask()
    }

    /// 取消任务
    func cancelTask(_ taskID: UUID) {
        runningTask?.cancel()
        runningTask = nil

        Task { @MainActor in
            cancelTaskUI(taskID)
        }
    }

    @MainActor
    private func cancelTaskUI(_ taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        tasks[index].status = .cancelled
        tasks[index].completedAt = Date()
        tasks[index].statusMessage = "已取消"

        saveTasks()
        endBackgroundTask()
    }

    /// 删除任务
    func deleteTask(_ taskID: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == taskID }),
           tasks[index].status == .inProgress {
            runningTask?.cancel()
            runningTask = nil
            endBackgroundTask()
        }

        tasks.removeAll { $0.id == taskID }
        saveTasks()
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
            .appendingPathComponent("translation_tasks.json")
    }

    func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: tasksFileURL)
        } catch {
            print("保存翻译任务失败: \(error)")
        }
    }

    func loadTasks() {
        guard FileManager.default.fileExists(atPath: tasksFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: tasksFileURL)
            tasks = try JSONDecoder().decode([TranslationTask].self, from: data)
        } catch {
            print("加载翻译任务失败: \(error)")
        }
    }
}

enum TranslationTaskError: LocalizedError {
    case emptySubtitle
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .emptySubtitle:
            return "字幕文件为空"
        case .parseFailed:
            return "字幕解析失败"
        }
    }
}
