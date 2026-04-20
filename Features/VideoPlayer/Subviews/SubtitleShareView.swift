import SwiftUI

// MARK: - Subtitle Share View
struct SubtitleShareView: View {
    let subtitlePath: String
    let videoTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var subtitleContent: String = ""
    @State private var tempSubtitleURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "caption.bubble.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("字幕文件")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(videoTitle)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(subtitlePath.split(separator: "/").last.map(String.init) ?? "未知文件")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 预览部分内容
                if !subtitleContent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("预览")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView {
                            Text(subtitleContent.prefix(500) + (subtitleContent.count > 500 ? "..." : ""))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .frame(maxHeight: 200)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // 下载按钮
                Button(action: shareSubtitle) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享/保存字幕")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSubtitleContent()
        }
    }

    private func loadSubtitleContent() {
        let url = URL(fileURLWithPath: subtitlePath)
        do {
            subtitleContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            subtitleContent = "无法读取字幕文件"
        }
    }

    private func shareSubtitle() {
        let url = URL(fileURLWithPath: subtitlePath)

        // 如果是 SRT 文件，复制到临时目录以便分享
        if subtitlePath.hasSuffix(".srt") {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(videoTitle.replacingOccurrences(of: " ", with: "_"))
                .appendingPathExtension("srt")

            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                tempSubtitleURL = tempURL
            } catch {
                print("复制字幕文件失败: \(error)")
                tempSubtitleURL = url
            }
        } else {
            tempSubtitleURL = url
        }

        showShareSheet = true
    }
}

// MARK: - Activity View (Share Sheet)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}