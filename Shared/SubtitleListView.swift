import SwiftUI

/// 定高可滑动的字幕列表组件
struct SubtitleListView: View {
    let entries: [SubtitleEntry]
    var showTranslation: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(entries) { entry in
                    SubtitleRowView(entry: entry, showTranslation: showTranslation)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

/// 单条字幕行
struct SubtitleRowView: View {
    let entry: SubtitleEntry
    var showTranslation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 时间戳
            Text(formatTimeRange(start: entry.startTime, end: entry.endTime))
                .font(.caption2)
                .foregroundColor(.secondary)

            // 原文
            Text(entry.text)
                .font(.body)
                .foregroundColor(.primary)

            // 翻译（如果有）
            if showTranslation, let translation = entry.translation {
                Text(translation)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }

    private func formatTimeRange(start: TimeInterval, end: TimeInterval) -> String {
        "\(formatTime(start)) → \(formatTime(end))"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    SubtitleListView(entries: [
        SubtitleEntry(index: 0, startTime: 0, endTime: 3.5, text: "Hello, welcome to this tutorial.", translation: "你好，欢迎观看本教程。"),
        SubtitleEntry(index: 1, startTime: 3.5, endTime: 7.2, text: "Today we're going to learn about SwiftUI.", translation: "今天我们将学习 SwiftUI。"),
        SubtitleEntry(index: 2, startTime: 7.2, endTime: 12.0, text: "Let's get started with the basics.", translation: "让我们从基础开始。")
    ], showTranslation: true)
    .frame(height: 300)
    .padding()
}
