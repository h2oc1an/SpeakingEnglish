import Foundation

class VocabularyService {
    static let shared = VocabularyService()

    private let repository: VocabularyRepository

    private init() {
        self.repository = VocabularyRepository()
    }

    func addWord(
        _ word: String,
        meaning: String? = nil,
        context: String? = nil,
        sourceVideoId: UUID? = nil,
        sourceTimestamp: TimeInterval? = nil
    ) throws -> VocabularyEntry {
        let entry = VocabularyEntry(
            word: word.lowercased().trimmingCharacters(in: .whitespaces),
            meaning: meaning,
            context: context,
            sourceVideoId: sourceVideoId,
            sourceTimestamp: sourceTimestamp
        )

        try repository.save(entry)
        return entry
    }

    func getAllWords(limit: Int? = nil, offset: Int? = nil) throws -> [VocabularyEntry] {
        return try repository.getAll(limit: limit, offset: offset)
    }

    func getWord(byId id: UUID) throws -> VocabularyEntry? {
        return try repository.getById(id)
    }

    func getDueForReview(limit: Int? = nil, offset: Int? = nil) throws -> [VocabularyEntry] {
        return try repository.getDueForReview(limit: limit, offset: offset)
    }

    func search(_ keyword: String, limit: Int? = nil, offset: Int? = nil) throws -> [VocabularyEntry] {
        return try repository.search(keyword, limit: limit, offset: offset)
    }

    func deleteWord(byId id: UUID) throws {
        try repository.delete(id)
    }

    func reviewWord(_ entry: VocabularyEntry, quality: Int) throws -> VocabularyEntry {
        let result = SM2Algorithm.calculate(
            quality: quality,
            repetitions: entry.repetitions,
            easinessFactor: entry.easinessFactor,
            interval: entry.interval
        )

        var updatedEntry = entry
        updatedEntry.repetitions = result.repetitions
        updatedEntry.easinessFactor = result.easinessFactor
        updatedEntry.interval = result.interval
        updatedEntry.nextReviewDate = result.nextReviewDate
        updatedEntry.lastReviewDate = Date()

        try repository.update(updatedEntry)
        return updatedEntry
    }

    func updateWord(_ entry: VocabularyEntry) throws {
        try repository.update(entry)
    }

    func getStatistics() throws -> LearningStatistics {
        let totalCount = try repository.getTotalCount()
        let dueCount = try repository.getDueCount()

        let today = Calendar.current.startOfDay(for: Date())
        let allWords = try repository.getAll(limit: nil, offset: nil)
        let reviewedToday = allWords.filter { entry in
            guard let lastReview = entry.lastReviewDate else { return false }
            return Calendar.current.isDate(lastReview, inSameDayAs: today)
        }

        return LearningStatistics(
            totalWords: totalCount,
            wordsToReview: dueCount,
            reviewedToday: reviewedToday.count
        )
    }
}

struct LearningStatistics {
    var totalWords: Int
    var wordsToReview: Int
    var reviewedToday: Int
}
