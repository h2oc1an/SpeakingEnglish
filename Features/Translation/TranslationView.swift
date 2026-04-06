import SwiftUI
import UniformTypeIdentifiers

struct TranslationView: View {
    @StateObject private var translationManager = TranslationTaskManager.shared
    @State private var showSubtitlePicker = false
    @State private var selectedSubtitleURL: URL?
    @State private var selectedSubtitleMode: SubtitleMode = .chinese
    @State private var selectedTaskID: UUID?

    private var selectedTask: TranslationTask? {
        translationManager.tasks.first { $0.id == selectedTaskID }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 字幕翻译区域
                Section {
                    if let url = selectedSubtitleURL {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.orange)
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }

                        Button(role: .destructive, action: {
                            selectedSubtitleURL = nil
                        }) {
                            Label("移除文件", systemImage: "trash")
                        }

                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.orange)
                            Picker("字幕模式", selection: $selectedSubtitleMode) {
                                ForEach(SubtitleMode.translationModes, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)

                        Button(action: {
                            startTranslation()
                        }) {
                            HStack {
                                Image(systemName: "character.bubble")
                                    .foregroundColor(.purple)
                                Text("开始翻译")
                                Spacer()
                            }
                        }
                    } else {
                        Button(action: { showSubtitlePicker = true }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.orange)
                                Text("选择字幕文件")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("字幕翻译")
                } footer: {
                    Text(subtitleFooterText)
                }

                // 翻译任务列表
                if !translationManager.tasks.isEmpty {
                    Section {
                        ForEach(translationManager.tasks) { task in
                            TranslationTaskRowView(task: task)
                                .onTapGesture {
                                    selectedTaskID = task.id
                                }
                                .contextMenu {
                                    if task.status == .completed, let resultPath = task.resultPath {
                                        ShareLink(item: URL(fileURLWithPath: resultPath)) {
                                            Label("导出字幕", systemImage: "square.and.arrow.up")
                                        }
                                    }

                                    Button {
                                        selectedTaskID = task.id
                                    } label: {
                                        Label("查看详情", systemImage: "info.circle")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        translationManager.deleteTask(task.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        translationManager.deleteTask(task.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if task.status == .inProgress {
                                        Button {
                                            translationManager.cancelTask(task.id)
                                        } label: {
                                            Label("取消", systemImage: "xmark")
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text("翻译任务")
                            Spacer()
                            Menu {
                                Button("清空已完成", role: .destructive) {
                                    translationManager.clearFinishedTasks()
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }

                // 空状态
                if translationManager.tasks.isEmpty && selectedSubtitleURL == nil {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "character.bubble")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)

                            Text("暂无翻译任务")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("选择字幕文件开始翻译")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle("翻译")
            .sheet(isPresented: Binding(
                get: { selectedTask != nil },
                set: { if !$0 { selectedTaskID = nil } }
            )) {
                if let task = selectedTask {
                    TranslationTaskDetailView(task: task)
                }
            }
            .sheet(isPresented: $showSubtitlePicker) {
                SubtitlePickerView { url in
                    selectedSubtitleURL = url
                    showSubtitlePicker = false
                }
            }
        }
    }

    private var subtitleFooterText: String {
        if selectedSubtitleURL == nil {
            return "选择 SRT、ASS 格式字幕文件"
        }
        switch selectedSubtitleMode {
        case .chinese:
            return "翻译为中文，用中文替换原文"
        case .bilingual:
            return "翻译为中文，同时保留原文"
        default:
            return ""
        }
    }

    private func startTranslation() {
        guard let url = selectedSubtitleURL else { return }

        translationManager.startTranslation(
            sourcePath: url.path,
            entryCount: 0,
            subtitleMode: selectedSubtitleMode
        )

        selectedSubtitleURL = nil
    }
}

// MARK: - Translation Task Row

struct TranslationTaskRowView: View {
    let task: TranslationTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.sourcePath.split(separator: "/").last.map(String.init) ?? "字幕文件")
                    .font(.headline)
                    .lineLimit(1)

                if task.subtitleMode == .bilingual {
                    Text("双语")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                } else {
                    Text("中文")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                Spacer()

                Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if task.status == .inProgress {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
            }

            Text(task.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch task.status {
        case .queued:
            Label("排队中", systemImage: "clock")
                .font(.caption)
                .foregroundColor(.orange)
        case .inProgress:
            Label("翻译中", systemImage: "character.bubble")
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

// MARK: - Translation Task Detail

struct TranslationTaskDetailView: View {
    let task: TranslationTask
    @Environment(\.dismiss) private var dismiss
    @State private var translatedContent: String?

    var body: some View {
        NavigationStack {
            List {
                Section("状态") {
                    LabeledContent("任务状态", value: task.status.rawValue)
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

                if task.status == .inProgress {
                    Section("进度") {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: task.progress)
                                .tint(.cyan)
                            Text(task.statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if task.status == .completed, let resultPath = task.resultPath {
                    Section("翻译结果") {
                        if let content = translatedContent {
                            ScrollView {
                                Text(content)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 300)
                        } else {
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }

                        ShareLink(item: URL(fileURLWithPath: resultPath)) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                                Text("分享/下载字幕")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("翻译任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadTranslatedContent()
            }
        }
    }

    private func loadTranslatedContent() {
        guard let resultPath = task.resultPath else { return }
        do {
            translatedContent = try String(contentsOfFile: resultPath, encoding: .utf8)
        } catch {
            translatedContent = "读取失败: \(error.localizedDescription)"
        }
    }
}

#Preview {
    TranslationView()
}
