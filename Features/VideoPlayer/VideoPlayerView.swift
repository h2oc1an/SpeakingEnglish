import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: Video
    @StateObject private var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hasInitialized = false
    @State private var showSubtitleShare = false

    init(video: Video) {
        self.video = video
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video))
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                if isLandscape {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .sheet(isPresented: $showSubtitleShare) {
            if let subtitlePath = video.subtitlePath {
                SubtitleShareView(subtitlePath: subtitlePath, videoTitle: video.title)
            }
        }
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                viewModel.setupPlayer(with: video)
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Portrait Layout
    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(.leading, 16)
                .padding(.top, 8)

                Spacer()

                // 字幕下载/分享按钮
                if video.subtitlePath != nil {
                    Button(action: { showSubtitleShare = true }) {
                        Image(systemName: "caption.bubble.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
            }

            VideoPlayer(player: viewModel.player)
                .frame(height: geometry.size.height * 0.35)

            // Minimal Subtitle (no background, with shadow)
            MinimalSubtitleView(
                currentSubtitle: viewModel.currentSubtitle,
                onWordTap: { word in
                    viewModel.handleWordTap(word)
                }
            )
            .padding(.horizontal)

            Spacer()

            VideoProgressView(
                currentTime: viewModel.currentTime,
                duration: viewModel.duration,
                onSeek: { time in
                    viewModel.seek(to: time)
                }
            )

            VideoControlBar(viewModel: viewModel)
        }

        wordPopupOverlay
    }

    // MARK: - Landscape Layout (Fullscreen Video)
    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            VideoPlayer(player: viewModel.player)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("返回")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.leading, 16)

                Spacer()
            }

            VStack {
                Spacer()

                MinimalSubtitleView(
                    currentSubtitle: viewModel.currentSubtitle,
                    onWordTap: { word in
                        viewModel.handleWordTap(word)
                    }
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }

            VStack {
                Spacer()

                VideoProgressView(
                    currentTime: viewModel.currentTime,
                    duration: viewModel.duration,
                    onSeek: { time in
                        viewModel.seek(to: time)
                    }
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
            }
        }

        wordPopupOverlay
    }

    // MARK: - Word Popup
    @ViewBuilder
    private var wordPopupOverlay: some View {
        if viewModel.showingWordPopup, let word = viewModel.selectedWord {
            WordPopupView(
                word: word,
                meaning: viewModel.selectedWordMeaning,
                context: viewModel.currentSubtitle?.text,
                onAddToVocabulary: {
                    viewModel.addToVocabulary()
                },
                onDismiss: {
                    viewModel.dismissWordPopup()
                }
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Subtitle Overlay View (with background)
struct SubtitleOverlayView: View {
    let currentSubtitle: SubtitleEntry?
    let onWordTap: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let subtitle = currentSubtitle {
                let (englishText, chineseText) = parseBilingualText(subtitle.text)

                EnglishSubtitleView(text: englishText, onWordTap: onWordTap)

                if !chineseText.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.3))

                    Text(chineseText)
                        .font(.system(size: 18))
                        .foregroundColor(.yellow)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("暂无字幕")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
        )
    }

    private func parseBilingualText(_ text: String) -> (String, String) {
        let separators = [" - ", " / ", "｜", " | ", "\n"]
        for separator in separators {
            if let range = text.range(of: separator) {
                let part1 = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let part2 = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !part1.isEmpty && !part2.isEmpty {
                    if containsChinese(part2) {
                        return (part1, part2)
                    } else if containsChinese(part1) {
                        return (part2, part1)
                    }
                }
            }
        }
        if containsChinese(text) {
            return extractEnglishAndChinese(from: text)
        }
        return (text, "")
    }

    private func containsChinese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }

    private func extractEnglishAndChinese(from text: String) -> (String, String) {
        var chineseStartIndex: String.Index?
        for (index, char) in text.enumerated() {
            let scalar = char.unicodeScalars.first!
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                chineseStartIndex = text.index(text.startIndex, offsetBy: index)
                break
            }
        }
        if let chineseIndex = chineseStartIndex {
            let englishPart = String(text[..<chineseIndex]).trimmingCharacters(in: .whitespaces)
            let chinesePart = String(text[chineseIndex...]).trimmingCharacters(in: .whitespaces)
            return (englishPart, chinesePart)
        }
        return (text, "")
    }
}

// MARK: - Minimal Subtitle View (Floating, No Background)
struct MinimalSubtitleView: View {
    let currentSubtitle: SubtitleEntry?
    let onWordTap: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let subtitle = currentSubtitle {
                let (englishText, chineseText) = parseBilingualText(subtitle.text)

                MinimalEnglishSubtitleView(text: englishText, onWordTap: onWordTap)

                if !chineseText.isEmpty {
                    Text(chineseText)
                        .font(.system(size: 16))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func parseBilingualText(_ text: String) -> (String, String) {
        let separators = [" - ", " / ", "｜", " | ", "\n"]
        for separator in separators {
            if let range = text.range(of: separator) {
                let part1 = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let part2 = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !part1.isEmpty && !part2.isEmpty {
                    if containsChinese(part2) {
                        return (part1, part2)
                    } else if containsChinese(part1) {
                        return (part2, part1)
                    }
                }
            }
        }
        if containsChinese(text) {
            return extractEnglishAndChinese(from: text)
        }
        return (text, "")
    }

    private func containsChinese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }

    private func extractEnglishAndChinese(from text: String) -> (String, String) {
        var chineseStartIndex: String.Index?
        for (index, char) in text.enumerated() {
            let scalar = char.unicodeScalars.first!
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                chineseStartIndex = text.index(text.startIndex, offsetBy: index)
                break
            }
        }
        if let chineseIndex = chineseStartIndex {
            let englishPart = String(text[..<chineseIndex]).trimmingCharacters(in: .whitespaces)
            let chinesePart = String(text[chineseIndex...]).trimmingCharacters(in: .whitespaces)
            return (englishPart, chinesePart)
        }
        return (text, "")
    }
}

// MARK: - English Subtitle View (with background)
struct EnglishSubtitleView: View {
    let text: String
    let onWordTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            FlowLayout(spacing: 6) {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    let cleanedWord = cleanWord(word)
                    if cleanedWord.count >= 2 {
                        Text(cleanedWord)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.4))
                            )
                            .onTapGesture {
                                onWordTap(cleanedWord)
                            }
                    } else {
                        Text(cleanedWord)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cleanWord(_ word: String) -> String {
        return word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}—–-"))
    }
}

// MARK: - Minimal English Subtitle View (no background, with shadow)
struct MinimalEnglishSubtitleView: View {
    let text: String
    let onWordTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                let cleanedWord = cleanWord(word)
                if cleanedWord.count >= 2 {
                    Text(cleanedWord)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .onTapGesture {
                            onWordTap(cleanedWord)
                        }
                } else {
                    Text(cleanedWord)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cleanWord(_ word: String) -> String {
        return word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}—–-"))
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let result = FlowResult(in: width, subviews: subviews, spacing: spacing)
        return CGSize(width: width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        let result = FlowResult(in: width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                let wordWidth = min(size.width, width - spacing)

                if x + wordWidth > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += wordWidth + spacing
            }

            height = y + rowHeight
        }
    }
}

// MARK: - Video Progress View
struct VideoProgressView: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 2) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track (gray background)
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 3)

                    // Progress (white fill)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, progressWidth(in: geometry.size.width)), height: 3)

                    // Thumb (small white dot)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .offset(x: progressWidth(in: geometry.size.width) - 3)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percent = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek(percent * duration)
                        }
                )
            }
            .frame(height: 20)

            // Time labels
            HStack {
                Text(formatTime(currentTime))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(formatTime(duration))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return totalWidth * CGFloat(currentTime / duration)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Video Control Bar
struct VideoControlBar: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var body: some View {
        HStack(spacing: 40) {
            Button(action: { viewModel.seekBackward() }) {
                Image(systemName: "gobackward.10")
                    .font(.title)
                    .foregroundColor(.white)
            }

            Button(action: { viewModel.togglePlayPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }

            Button(action: { viewModel.seekForward() }) {
                Image(systemName: "goforward.10")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

// MARK: - Word Popup View
struct WordPopupView: View {
    let word: String
    let meaning: String?
    let context: String?
    let onAddToVocabulary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 20) {
                HStack {
                    Text("单词释义")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                Text(word)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)

                if let meaning = meaning, !meaning.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.green)
                            Text("词典释义")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text(meaning)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)

                        Text("正在查询释义...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                if let ctx = context, !ctx.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("原文")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(ctx)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        onAddToVocabulary()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加到生词本")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button(action: onDismiss) {
                        Text("关闭")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 24)
        }
    }
}

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
