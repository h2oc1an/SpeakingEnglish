import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @StateObject private var taskManager = TranscriptionTaskManager.shared
    @State private var showVideoPicker = false
    @State private var showingTaskDetail: TranscriptionTask?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastStyle: ToastView.ToastStyle = .success

    var body: some View {
        NavigationStack {
            Form {
                // 视频选择
                Section {
                    Button(action: { showVideoPicker = true }) {
                        HStack {
                            Image(systemName: "film")
                                .foregroundColor(.blue)
                            Text(viewModel.selectedVideoURL?.lastPathComponent ?? "选择视频文件")
                            Spacer()
                            if viewModel.selectedVideoURL != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    if viewModel.selectedVideoURL != nil {
                        Button(role: .destructive, action: {
                            viewModel.clearSelection()
                        }) {
                            Label("移除视频", systemImage: "trash")
                        }

                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.orange)
                            Picker("字幕模式", selection: $viewModel.subtitleMode) {
                                ForEach(SubtitleMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 4)
                        }

                        Button(action: {
                            viewModel.startTranscription()
                        }) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.purple)
                                Text("开始转录")
                                Spacer()
                            }
                        }
                        .disabled(!viewModel.canTranscribe)
                    }
                } header: {
                    Text("视频")
                } footer: {
                    Text(subtitleFooterText)
                }

                // 任务列表
                if !taskManager.tasks.isEmpty {
                    Section {
                        ForEach(taskManager.tasks) { task in
                            TaskRowView(task: task)
                                .onTapGesture {
                                    if task.status == .completed || task.status == .failed {
                                        showingTaskDetail = task
                                    }
                                }
                                .contextMenu {
                                    if task.status == .completed {
                                        Button {
                                            viewModel.importTask(task)
                                            showToastMessage("已导入到视频库", style: .success)
                                        } label: {
                                            Label("导入到视频库", systemImage: "square.and.arrow.down")
                                        }
                                    }

                                    Button {
                                        showingTaskDetail = task
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
                    } header: {
                        HStack {
                            Text("转录任务")
                            Spacer()
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
                }
            }
            .navigationTitle("转录")
            .sheet(isPresented: $showVideoPicker) {
                DocumentPickerView(
                    supportedTypes: [.mpeg4Movie, .quickTimeMovie, .movie],
                    pickerMode: .open
                ) { urls in
                    if let url = urls.first {
                        viewModel.selectVideo(url: url)
                    }
                    showVideoPicker = false
                }
            }
            .sheet(item: $showingTaskDetail) { task in
                TaskDetailView(task: task)
            }
            .toast(isPresented: $showToast, message: toastMessage, style: toastStyle)
        }
    }

    private var subtitleFooterText: String {
        switch viewModel.subtitleMode {
        case .original:
            return "选择 MP4 或 MOV 格式的视频，语音将被转录为字幕"
        case .chinese:
            return "转录并翻译为中文，只显示中文字幕"
        case .bilingual:
            return "转录原语言并翻译为中文，同时显示原文和中文"
        }
    }

    private func showToastMessage(_ message: String, style: ToastView.ToastStyle) {
        toastMessage = message
        toastStyle = style
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    TranscriptionView()
}
