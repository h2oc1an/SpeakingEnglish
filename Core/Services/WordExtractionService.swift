import Foundation

class WordExtractionService {

    static let shared = WordExtractionService()

    private init() {}

    func extractWords(from text: String) -> [Word] {
        let cleanedText = cleanText(text)
        let tokens = cleanedText.components(separatedBy: .whitespaces)

        var words: [Word] = []
        for token in tokens {
            let word = token.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if isValidWord(word) {
                words.append(Word(text: word))
            }
        }

        return words
    }

    func extractUniqueWords(from text: String) -> Set<String> {
        let words = extractWords(from: text)
        return Set(words.map { $0.text })
    }

    func filterMeaningfulWords(_ words: [Word]) -> [Word] {
        return words.filter { isMeaningfulWord($0.text) }
    }

    private func cleanText(_ text: String) -> String {
        // Keep only letters and spaces
        let allowed = CharacterSet.letters.union(.whitespaces)
        return text.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
    }

    private func isValidWord(_ word: String) -> Bool {
        // Must be at least 2 characters
        guard word.count >= 2 else { return false }

        // Must contain only letters
        guard word.allSatisfy({ $0.isLetter }) else { return false }

        return true
    }

    private func isMeaningfulWord(_ word: String) -> Bool {
        // Filter out stop words
        return !StopWords.list.contains(word.lowercased())
    }
}
