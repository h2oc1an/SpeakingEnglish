import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @StateObject private var taskManager = TranscriptionTaskManager.shared
    @State private var showVideoPicker = false
    @State private var showingTaskDetail: TranscriptionTask?

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
                    Text("选择 MP4 或 MOV 格式的视频，语音将被转录为英文字幕")
                }

                // 消息
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                    }
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        taskManager.deleteTask(task.id)
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
        }
    }
}

#Preview {
    TranscriptionView()
}
