import Foundation
import AVFoundation
import Combine

class VideoPlayerViewModel: ObservableObject {
    let video: Video

    @Published var player: AVPlayer
    @Published var currentSubtitle: SubtitleEntry?
    @Published var selectedWord: String?
    @Published var selectedWordMeaning: String?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var showingWordPopup: Bool = false
    @Published var playbackRate: Float = 1.0
    @Published var bookmarks: [VideoBookmark] = []
    @Published var showingBookmarkSheet: Bool = false
    @Published var showingAddBookmark: Bool = false

    private var subtitles: [SubtitleEntry] = []
    private var timeObserver: Any?
    private let srtParser = SRTSubtitleParser()
    private let assParser = ASSSubtitleParser()
    private let videoRepository = VideoRepository.shared
    private let bookmarkRepository = VideoBookmarkRepository()

    init(video: Video) {
        self.video = video
        self.player = AVPlayer()
        loadPlaybackSettings()
        loadBookmarks()
    }

    private func loadBookmarks() {
        do {
            bookmarks = try bookmarkRepository.getAll(for: video.id)
        } catch {
            print("Failed to load bookmarks: \(error)")
        }
    }

    private func loadPlaybackSettings() {
        playbackRate = videoRepository.getPlaybackRate(for: video.id) ?? 1.0
    }

    func setupPlayer(with video: Video) {
        let url = URL(fileURLWithPath: video.localPath)
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)

        // Get duration
        Task { @MainActor in
            if let durationTime = player.currentItem?.asset.duration {
                self.duration = CMTimeGetSeconds(durationTime)
            }
        }

        // Load subtitles
        loadSubtitles()

        // Add time observer
        addTimeObserver()

        // Observe playback state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // Restore last playback position
        let lastPosition = videoRepository.getLastPlaybackPosition(for: video.id)
        if lastPosition > 0 && lastPosition < duration - 5 {
            seek(to: lastPosition)
        }
    }

    private func loadSubtitles() {
        guard let subtitlePath = video.subtitlePath else { return }

        let url = URL(fileURLWithPath: subtitlePath)
        let fileExtension = url.pathExtension.lowercased()

        do {
            if fileExtension == "srt" {
                subtitles = try srtParser.parse(fileURL: url)
            } else if fileExtension == "ass" || fileExtension == "ssa" {
                subtitles = try assParser.parse(fileURL: url)
            }
        } catch {
            print("Failed to load subtitles: \(error)")
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)
            self.updateCurrentSubtitle()
        }
    }

    private func updateCurrentSubtitle() {
        let current = currentTime
        currentSubtitle = subtitles.first { entry in
            entry.startTime <= current && entry.endTime >= current
        }
    }

    func handleWordTap(_ word: String) {
        let cleanedWord = word.lowercased()
        selectedWord = cleanedWord
        selectedWordMeaning = nil // Reset while loading
        showingWordPopup = true

        // Look up in dictionary (async)
        DictionaryService.shared.lookup(cleanedWord) { [weak self] meaning in
            DispatchQueue.main.async {
                self?.selectedWordMeaning = meaning
            }
        }
    }

    func addToVocabulary() {
        guard let word = selectedWord else { return }

        do {
            // Use dictionary meaning if available, otherwise use user-provided meaning
            let meaning = selectedWordMeaning ?? "未找到释义"
            _ = try VocabularyService.shared.addWord(
                word,
                meaning: meaning,
                context: currentSubtitle?.text,
                sourceVideoId: video.id,
                sourceTimestamp: currentTime
            )
            showingWordPopup = false
        } catch {
            print("Failed to add word: \(error)")
        }
    }

    func dismissWordPopup() {
        showingWordPopup = false
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
            player.rate = playbackRate
        }
        isPlaying.toggle()
    }

    func setPlaybackSpeed(_ speed: Float) {
        playbackRate = speed
        if isPlaying {
            player.rate = speed
        }
        videoRepository.savePlaybackRate(for: video.id, rate: speed)
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
    }

    func seekForward() {
        let newTime = min(currentTime + 10, duration)
        seek(to: newTime)
    }

    func seekBackward() {
        let newTime = max(currentTime - 10, 0)
        seek(to: newTime)
    }

    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        seek(to: 0)
    }

    func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        NotificationCenter.default.removeObserver(self)

        // Save playback position
        videoRepository.saveLastPlaybackPosition(for: video.id, position: currentTime)
    }

    // MARK: - Bookmarks

    func addBookmark(note: String? = nil) {
        let bookmark = VideoBookmark(
            videoId: video.id,
            timestamp: currentTime,
            note: note
        )
        do {
            try bookmarkRepository.save(bookmark)
            loadBookmarks()
        } catch {
            print("Failed to add bookmark: \(error)")
        }
    }

    func deleteBookmark(_ bookmark: VideoBookmark) {
        do {
            try bookmarkRepository.delete(bookmark.id)
            loadBookmarks()
        } catch {
            print("Failed to delete bookmark: \(error)")
        }
    }

    func jumpToBookmark(_ bookmark: VideoBookmark) {
        seek(to: bookmark.timestamp)
    }
}
