import Foundation
import Combine

class ReviewViewModel: ObservableObject {
    @Published var wordsToReview: [VocabularyEntry] = []
    @Published var currentWord: VocabularyEntry?
    @Published var isLoading: Bool = false
    @Published var isCompleted: Bool = false
    @Published var reviewedCount: Int = 0

    var progress: (current: Int, total: Int) {
        let current = reviewedCount + 1
        let total = wordsToReview.count
        return (min(current, total), total)
    }

    private var currentIndex: Int = 0

    func startReview() {
        isLoading = true
        isCompleted = false
        reviewedCount = 0
        currentIndex = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.loadWordsForReview()
        }
    }

    private func loadWordsForReview() {
        do {
            wordsToReview = try VocabularyService.shared.getDueForReview()
            isLoading = false

            if wordsToReview.isEmpty {
                isCompleted = true
                currentWord = nil
            } else {
                currentWord = wordsToReview[currentIndex]
            }
        } catch {
            print("Failed to load words for review: \(error)")
            isLoading = false
        }
    }

    func rateWord(quality: Int) {
        guard let word = currentWord else { return }

        do {
            _ = try VocabularyService.shared.reviewWord(word, quality: quality)
            reviewedCount += 1
            moveToNextWord()
        } catch {
            print("Failed to rate word: \(error)")
        }
    }

    private func moveToNextWord() {
        currentIndex += 1

        if currentIndex >= wordsToReview.count {
            currentWord = nil
            isCompleted = true
        } else {
            currentWord = wordsToReview[currentIndex]
        }
    }
}
