import SwiftUI

// MARK: - Video Control Bar
struct VideoControlBar: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var showSpeedPicker = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

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

            // Speed selector
            Button(action: { showSpeedPicker = true }) {
                Text(String(format: "%.2gx", viewModel.playbackRate))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .sheet(isPresented: $showSpeedPicker) {
            SpeedPickerSheet(
                currentSpeed: viewModel.playbackRate,
                speeds: speeds,
                onSelect: { speed in
                    viewModel.setPlaybackSpeed(speed)
                    showSpeedPicker = false
                }
            )
            .presentationDetents([.height(300)])
        }
    }
}

// MARK: - Speed Picker Sheet
struct SpeedPickerSheet: View {
    let currentSpeed: Float
    let speeds: [Float]
    let onSelect: (Float) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(speeds, id: \.self) { speed in
                    Button(action: { onSelect(speed) }) {
                        HStack {
                            Text(String(format: "%.2gx", speed))
                                .font(.headline)
                            Spacer()
                            if abs(speed - currentSpeed) < 0.01 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("播放速度")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}