import SwiftUI

struct TranscriptionTasksView: View {
    @StateObject private var taskManager = TranscriptionTaskManager.shared
    @StateObject private var translationManager = TranslationTaskManager.shared
    @State private var selectedTaskID: UUID?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastStyle: ToastView.ToastStyle = .success

    private var selectedTask: TranscriptionTask? {
        taskManager.tasks.first { $0.id == selectedTaskID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if taskManager.tasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .navigationTitle("转录任务")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("清理已完成任务", role: .destructive) {
                            taskManager.tasks.removeAll { $0.status == .completed || $0.status == .failed }
                            taskManager.saveTasks()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedTask != nil },
                set: { if !$0 { selectedTaskID = nil } }
            )) {
                if let task = selectedTask {
                    TaskDetailView(task: task)
                }
            }
            .toast(isPresented: $showToast, message: toastMessage, style: toastStyle)
        }
    }

    private func showToastMessage(_ message: String, style: ToastView.ToastStyle) {
        toastMessage = message
        toastStyle = style
        withAnimation {
            showToast = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("暂无转录任务")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("在上传页面选择视频即可开始转录")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var taskList: some View {
        List {
            ForEach(taskManager.tasks) { task in
                TaskRowView(task: task)
                    .onTapGesture {
                        if task.status == .completed || task.status == .failed {
                            selectedTaskID = task.id
                        }
                    }
                    .contextMenu {
                        if task.status == .completed {
                            Button {
                                importTask(task)
                                showToastMessage("已导入到视频库", style: .success)
                            } label: {
                                Label("导入到视频库", systemImage: "square.and.arrow.down")
                            }
                        }

                        Button {
                            selectedTaskID = task.id
                        } label: {
                            Label("查看详情", systemImage: "info.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            taskManager.deleteTask(task.id)
                            showToastMessage("任务已删除", style: .info)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            taskManager.deleteTask(task.id)
                            showToastMessage("任务已删除", style: .info)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if task.status == .inProgress {
                            Button {
                                taskManager.cancelTask(task.id)
                            } label: {
                                Label("取消", systemImage: "xmark")
                            }
                            .tint(.orange)
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func importTask(_ task: TranscriptionTask) {
        let uploadService = UploadService.shared

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

            } catch {
                print("导入失败: \(error)")
            }
        }
    }
}

struct TaskRowView: View {
    let task: TranscriptionTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.videoTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(task.subtitleMode.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tagBackgroundColor)
                    .foregroundColor(tagForegroundColor)
                    .cornerRadius(4)

                Spacer()

                statusBadge
            }

            Text(task.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            if task.status == .inProgress {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
            }

            Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var tagBackgroundColor: Color {
        switch task.subtitleMode {
        case .original:
            return Color.gray.opacity(0.2)
        case .chinese:
            return Color.blue.opacity(0.2)
        case .bilingual:
            return Color.orange.opacity(0.2)
        }
    }

    private var tagForegroundColor: Color {
        switch task.subtitleMode {
        case .original:
            return .gray
        case .chinese:
            return .blue
        case .bilingual:
            return .orange
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch task.status {
        case .queued:
            Label("排队中", systemImage: "clock")
                .font(.caption)
                .foregroundColor(.orange)
        case .inProgress:
            Label("转录中", systemImage: "waveform")
                .font(.caption)
                .foregroundColor(.blue)
        case .completed:
            Label("已完成", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .failed:
            Label("失败", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        case .cancelled:
            Label("已取消", systemImage: "minus.circle")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct TaskDetailView: View {
    let task: TranscriptionTask
    @Environment(\.dismiss) private var dismiss
    @StateObject private var translationManager = TranslationTaskManager.shared
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importSuccess = false
    @State private var translationTaskID: UUID?

    // 复制task中的数据避免内存问题
    private let videoTitle: String
    private let videoPath: String
    private let subtitlePath: String?
    private let entries: [SubtitleEntry]

    private let uploadService = UploadService.shared
    private let transcriptionService = TranscriptionService.shared

    init(task: TranscriptionTask) {
        self.task = task
        self.videoTitle = task.videoTitle
        self.videoPath = task.videoPath
        self.subtitlePath = task.subtitlePath
        self.entries = task.entries ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    LabeledContent("视频标题", value: videoTitle)
                    LabeledContent("状态", value: task.status.rawValue)
                    LabeledContent("创建时间", value: task.createdAt.formatted())
                    if let completedAt = task.completedAt {
                        LabeledContent("完成时间", value: completedAt.formatted())
                    }
                }

                if task.status == .failed, let error = task.errorMessage {
                    Section("错误信息") {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if task.status == .completed {
                    Section {
                        Button(action: importToLibrary) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(.blue)
                                Text("导入到视频库")
                                Spacer()
                                if isImporting {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isImporting)

                        // 下载原始字幕
                        if let subPath = subtitlePath {
                            ShareLink(item: URL(fileURLWithPath: subPath)) {
                                HStack {
                                    Image(systemName: "arrow.down.doc")
                                        .foregroundColor(.green)
                                    Text("下载原始字幕")
                                    Spacer()
                                }
                            }
                        }

                        // 翻译按钮 - 只有原字幕模式才需要翻译
                        if let subPath = subtitlePath, task.subtitleMode == .original {
                            Button(action: { startTranslation(subtitlePath: subPath) }) {
                                HStack {
                                    Image(systemName: "character.bubble")
                                        .foregroundColor(.cyan)
                                    Text("翻译字幕为中文")
                                    Spacer()
                                    if let taskID = translationTaskID,
                                       let transTask = translationManager.tasks.first(where: { $0.id == taskID }),
                                       transTask.status == .inProgress {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(translationTaskID != nil)
                        }
                    }
                }

                // 翻译任务进度
                if let taskID = translationTaskID,
                   let transTask = translationManager.tasks.first(where: { $0.id == taskID }) {
                    Section("翻译进度") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(transTask.status.rawValue)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(transTask.progress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            ProgressView(value: transTask.progress)
                                .tint(.cyan)

                            Text(transTask.statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if transTask.status == .completed, let resultPath = transTask.resultPath {
                            Button(action: { importWithTranslation(translatedPath: resultPath) }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .foregroundColor(.green)
                                    Text("导入（含翻译字幕）")
                                    Spacer()
                                    if isImporting {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isImporting)

                            // 下载翻译字幕
                            ShareLink(item: URL(fileURLWithPath: resultPath)) {
                                HStack {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .foregroundColor(.orange)
                                    Text("下载翻译字幕")
                                    Spacer()
                                }
                            }
                        }

                        if transTask.status != .inProgress && transTask.status != .completed {
                            Button(role: .destructive, action: { deleteTranslationTask(taskID) }) {
                                Label("删除翻译任务", systemImage: "trash")
                            }
                        }
                    }
                }

                if !entries.isEmpty {
                    Section("转录结果 (\(entries.count) 条)") {
                        SubtitleListView(entries: Array(entries.prefix(50)), showTranslation: true)
                            .frame(height: 300)
                    }
                }

                if let path = subtitlePath {
                    Section("字幕文件") {
                        Text(path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("任务详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("导入成功", isPresented: $importSuccess) {
                Button("确定") { dismiss() }
            } message: {
                Text("视频 \"\(videoTitle)\" 已导入到视频库")
            }
            .alert("导入失败", isPresented: .init(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("确定") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func startTranslation(subtitlePath: String) {
        guard translationTaskID == nil else { return }

        let taskID = translationManager.startTranslation(
            sourcePath: subtitlePath,
            entryCount: entries.count
        )
        translationTaskID = taskID
    }

    private func deleteTranslationTask(_ taskID: UUID) {
        translationManager.deleteTask(taskID)
        if translationTaskID == taskID {
            translationTaskID = nil
        }
    }

    private func importToLibrary() {
        guard !isImporting else { return }
        isImporting = true

        Task { @MainActor in
            do {
                let thumbnailPath = uploadService.generateThumbnail(for: videoPath)
                let duration = uploadService.getVideoDuration(for: videoPath)

                var subPath: String?
                if let originalSubtitlePath = subtitlePath {
                    subPath = try uploadService.copySubtitleToDocuments(from: URL(fileURLWithPath: originalSubtitlePath))
                }

                let video = Video(
                    title: videoTitle,
                    localPath: videoPath,
                    thumbnailPath: thumbnailPath,
                    duration: duration,
                    subtitlePath: subPath
                )

                let repository = VideoRepository()
                try repository.save(video)

                isImporting = false
                importSuccess = true

            } catch {
                isImporting = false
                importError = error.localizedDescription
            }
        }
    }

    private func importWithTranslation(translatedPath: String) {
        guard !isImporting else { return }
        isImporting = true

        Task { @MainActor in
            do {
                let thumbnailPath = uploadService.generateThumbnail(for: videoPath)
                let duration = uploadService.getVideoDuration(for: videoPath)

                let subPath = try uploadService.copySubtitleToDocuments(from: URL(fileURLWithPath: translatedPath))

                let video = Video(
                    title: videoTitle,
                    localPath: videoPath,
                    thumbnailPath: thumbnailPath,
                    duration: duration,
                    subtitlePath: subPath
                )

                let repository = VideoRepository()
                try repository.save(video)

                isImporting = false
                importSuccess = true

            } catch {
                isImporting = false
                importError = error.localizedDescription
            }
        }
    }
}

#Preview {
    TranscriptionTasksView()
}
