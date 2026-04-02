import SwiftUI

enum SettingsTab {
    case settings
    case review
}

struct SettingsAndReviewView: View {
    @State private var selectedTab: SettingsTab = .settings
    @State private var statistics: LearningStatistics?
    @State private var showingResetConfirmation: Bool = false
    @StateObject private var reviewViewModel = ReviewViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Picker
                Picker("功能", selection: $selectedTab) {
                    Text("设置").tag(SettingsTab.settings)
                    Text("复习").tag(SettingsTab.review)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == .settings {
                    settingsContent
                } else {
                    reviewContent
                }
            }
            .navigationTitle("设置与复习")
            .onAppear {
                loadStatistics()
            }
        }
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        List {
            Section {
                if let stats = statistics {
                    LabeledContent("总单词数", value: "\(stats.totalWords)")
                    LabeledContent("待复习", value: "\(stats.wordsToReview)")
                    LabeledContent("今日已学", value: "\(stats.reviewedToday)")
                }
            } header: {
                Text("学习统计")
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("关于应用", systemImage: "info.circle")
                }

                NavigationLink {
                    HelpView()
                } label: {
                    Label("使用帮助", systemImage: "questionmark.circle")
                }
            } header: {
                Text("信息")
            }

            Section {
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("重置所有数据", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } header: {
                Text("数据管理")
            } footer: {
                Text("此操作将删除所有单词和复习记录，且无法恢复。")
            }
        }
        .listStyle(.insetGrouped)
        .confirmationDialog("确认重置", isPresented: $showingResetConfirmation) {
            Button("重置所有数据", role: .destructive) {
                resetAllData()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除所有数据吗？此操作不可撤销。")
        }
    }

    // MARK: - Review Content

    private var reviewContent: some View {
        Group {
            if reviewViewModel.isLoading {
                ProgressView("加载中...")
            } else if reviewViewModel.wordsToReview.isEmpty {
                EmptyReviewView()
            } else if reviewViewModel.isCompleted {
                ReviewCompletedView(
                    reviewedCount: reviewViewModel.reviewedCount,
                    onStartAgain: { reviewViewModel.startReview() }
                )
            } else if let currentWord = reviewViewModel.currentWord {
                ReviewCardView(
                    word: currentWord,
                    progress: reviewViewModel.progress,
                    onRate: { quality in
                        reviewViewModel.rateWord(quality: quality)
                    }
                )
            }
        }
        .onAppear {
            reviewViewModel.startReview()
        }
    }

    // MARK: - Actions

    private func loadStatistics() {
        do {
            statistics = try VocabularyService.shared.getStatistics()
        } catch {
            print("Failed to load statistics: \(error)")
        }
    }

    private func resetAllData() {
        print("Reset all data requested")
    }
}

// MARK: - Empty Review View

struct EmptyReviewView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("太棒了！")
                .font(.title)
                .fontWeight(.bold)

            Text("目前没有需要复习的单词")
                .font(.body)
                .foregroundColor(.secondary)

            Text("继续学习更多单词吧")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Review Completed View

struct ReviewCompletedView: View {
    let reviewedCount: Int
    let onStartAgain: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("复习完成！")
                .font(.title)
                .fontWeight(.bold)

            Text("已复习 \(reviewedCount) 个单词")
                .font(.body)
                .foregroundColor(.secondary)

            Button(action: onStartAgain) {
                Text("再复习一次")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Review Card View

struct ReviewCardView: View {
    let word: VocabularyEntry
    let progress: (current: Int, total: Int)
    let onRate: (Int) -> Void

    @State private var showingAnswer: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack {
                Text("进度: \(progress.current)/\(progress.total)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let nextReview = word.lastReviewDate {
                    Text("上次: \(nextReview, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            Spacer()

            // Word card
            VStack(spacing: 16) {
                Text(word.word)
                    .font(.system(size: 36, weight: .bold))

                if showingAnswer {
                    if let meaning = word.meaning, !meaning.isEmpty {
                        Text(meaning)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    }

                    if let context = word.context, !context.isEmpty {
                        Text(context)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .padding(.top, 8)
                    }
                } else {
                    Text("点击查看答案")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                if !showingAnswer {
                    Button(action: { withAnimation { showingAnswer = true } }) {
                        Text("显示答案")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Text("回忆程度如何？")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(SM2Algorithm.Quality.allCases, id: \.rawValue) { quality in
                            Button(action: { onRate(quality.rawValue) }) {
                                Text(quality.displayName)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(qualityButtonColor(quality))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func qualityButtonColor(_ quality: SM2Algorithm.Quality) -> Color {
        switch quality {
        case .forgotten:
            return Color(hex: "FF3B30")
        case .hard:
            return Color(hex: "FF9500")
        case .difficult:
            return Color(hex: "FFCC00")
        case .good:
            return Color(hex: "34C759")
        case .easy:
            return Color(hex: "34C759")
        case .perfect:
            return Color(hex: "007AFF")
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "book.and.wizard")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("SpeakingEnglish")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("版本 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            Section {
                Text("一款帮助你通过视频学习英语的应用。在观看视频时，可以自动提取字幕中的单词，方便学习和复习。")
                    .font(.body)
            } header: {
                Text("介绍")
            }

            Section {
                LabeledContent("开发", value: "H2Ocean")
                LabeledContent("设计", value: "H2Ocean")
            } header: {
                Text("Credits")
            }
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. 观看视频")
                        .font(.headline)
                    Text("在首页选择要学习的视频，观看时字幕会同步显示。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("2. 点击单词")
                        .font(.headline)
                    Text("在字幕中点击任意单词，可以将其添加到生词本。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("3. 复习记忆")
                        .font(.headline)
                    Text("使用 SM-2 间隔重复算法，科学安排复习时间，提高记忆效率。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("使用方法")
            }

            Section {
                AccordionView(title: "什么是 SM-2 算法？", content: "SM-2 是一种间隔重复算法，由 Piotr Wozniak 发明。它根据你对每个单词的记忆程度，计算最佳复习间隔，帮助你更高效地记忆单词。")
                AccordionView(title: "如何获得示例视频？", content: "将 MP4 格式的视频和对应字幕文件放入 Resources/SampleVideos 目录即可。支持 SRT 和 ASS 格式的字幕文件。")
            } header: {
                Text("常见问题")
            }
        }
    }
}

// MARK: - Accordion View

struct AccordionView: View {
    let title: String
    let content: String
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isExpanded {
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsAndReviewView()
}
