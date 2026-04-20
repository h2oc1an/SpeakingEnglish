import SwiftUI

// MARK: - Subtitle Overlay View (with background)
struct SubtitleOverlayView: View {
    let currentSubtitle: SubtitleEntry?
    let onWordTap: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let subtitle = currentSubtitle {
                let (englishText, chineseText) = BilingualTextParser.parse(subtitle.text)

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
}

// MARK: - Minimal Subtitle View (Floating, No Background)
struct MinimalSubtitleView: View {
    let currentSubtitle: SubtitleEntry?
    let onWordTap: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let subtitle = currentSubtitle {
                let (englishText, chineseText) = BilingualTextParser.parse(subtitle.text)

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