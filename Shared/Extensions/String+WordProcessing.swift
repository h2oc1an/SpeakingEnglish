import Foundation

extension String {
    func extractWords() -> [String] {
        let cleaned = self.unicodeScalars
            .filter { CharacterSet.letters.contains($0) }
            .map { String($0) }
            .joined()

        return cleaned.components(separatedBy: .whitespaces)
            .map { $0.lowercased() }
            .filter { $0.count >= 2 }
    }

    func extractUniqueWords() -> Set<String> {
        return Set(extractWords())
    }

    func removePunctuation() -> String {
        return self.unicodeScalars
            .filter { !CharacterSet.punctuationCharacters.contains($0) }
            .map { String($0) }
            .joined()
    }

    var isValidWord: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.allSatisfy { $0.isLetter }
    }
}
