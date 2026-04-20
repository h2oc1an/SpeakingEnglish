import SwiftUI

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
                Text(TimeFormatter.formatMinutesSeconds(currentTime))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(TimeFormatter.formatMinutesSeconds(duration))
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
}