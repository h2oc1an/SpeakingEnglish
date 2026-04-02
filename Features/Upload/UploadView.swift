import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @StateObject private var viewModel = UploadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showVideoPicker = false
    @State private var showSubtitlePicker = false

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
                            viewModel.selectedVideoURL = nil
                        }) {
                            Label("移除视频", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("视频")
                } footer: {
                    Text("支持 MP4, MOV 格式")
                }

                // 字幕选择/生成
                Section {
                    Button(action: { showSubtitlePicker = true }) {
                        HStack {
                            Image(systemName: "captions.bubble")
                                .foregroundColor(.orange)
                            Text(viewModel.selectedSubtitleURL?.lastPathComponent ?? "选择字幕文件（可选）")
                            Spacer()
                            if viewModel.selectedSubtitleURL != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    if viewModel.selectedSubtitleURL != nil {
                        Button(role: .destructive, action: {
                            viewModel.selectedSubtitleURL = nil
                        }) {
                            Label("移除字幕", systemImage: "trash")
                        }

                        // 翻译按钮
                        Button(action: {
                            Task {
                                await viewModel.translateSubtitle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "character.bubble")
                                    .foregroundColor(.cyan)
                                Text("翻译字幕为中文")
                                Spacer()
                                if viewModel.isTranslating {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(viewModel.isTranslating)

                        // 翻译进度
                        if viewModel.isTranslating {
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressView(value: viewModel.translateProgress)
                                    .tint(.cyan)

                                Text(viewModel.translateStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("字幕")
                } footer: {
                    Text("支持 SRT, ASS, SSA 格式")
                }

                // 标题输入
                Section {
                    TextField("视频标题", text: $viewModel.videoTitle)
                } header: {
                    Text("信息")
                }

                // 上传进度
                if viewModel.isUploading {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ProgressView(value: viewModel.uploadProgress)
                                Text("\(Int(viewModel.uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // 错误/成功消息
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
            }
            .navigationTitle("上传视频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("上传") {
                        viewModel.upload { success in
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canUpload)
                }
            }
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
            .sheet(isPresented: $showSubtitlePicker) {
                SubtitlePickerView { url in
                    viewModel.selectSubtitle(url: url)
                    showSubtitlePicker = false
                }
            }
        }
    }
}

#Preview {
    UploadView()
}
