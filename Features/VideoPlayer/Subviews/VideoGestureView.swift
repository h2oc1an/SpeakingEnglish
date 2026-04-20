import SwiftUI

// MARK: - Video Gesture View
struct VideoGestureView: View {
    let onSeek: (TimeInterval) -> Void
    let onDoubleTap: () -> Void

    @State private var seekDelta: TimeInterval = 0
    @State private var showSeekIndicator = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Seek indicator
                if showSeekIndicator {
                    SeekIndicatorView(delta: seekDelta)
                }

                // Gesture recognizers
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                let horizontal = value.translation.width
                                if abs(horizontal) > 100 {
                                    let delta = horizontal > 0 ? 10.0 : -10.0
                                    seekDelta = delta
                                    showSeekIndicator = true
                                    onSeek(delta)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        showSeekIndicator = false
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                onDoubleTap()
                            }
                    )
            }
        }
    }
}

// MARK: - Seek Indicator View
struct SeekIndicatorView: View {
    let delta: TimeInterval

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: delta < 0 ? "gobackward.10" : "goforward.10")
                .font(.title)
            Text(delta < 0 ? "-10s" : "+10s")
                .font(.headline)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}