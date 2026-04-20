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
        .sheet(isPresented: $viewModel.showingBookmarkSheet) {
            BookmarkListSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingAddBookmark) {
            AddBookmarkSheet(viewModel: viewModel)
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

                // 书签按钮
                Button(action: { viewModel.showingBookmarkSheet = true }) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.trailing, 8)

                // 添加书签按钮
                Button(action: { viewModel.showingAddBookmark = true }) {
                    Image(systemName: "bookmark.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            VideoPlayer(player: viewModel.player)
                .frame(height: geometry.size.height * 0.35)
                .overlay(
                    VideoGestureView(
                        onSeek: { delta in
                            let newTime = max(0, min(viewModel.duration, viewModel.currentTime + delta))
                            viewModel.seek(to: newTime)
                        },
                        onDoubleTap: {
                            viewModel.togglePlayPause()
                        }
                    )
                )

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
