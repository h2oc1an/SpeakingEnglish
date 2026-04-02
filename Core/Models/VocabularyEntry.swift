import Foundation

struct VocabularyEntry: Identifiable, Codable {
    let id: UUID
    var word: String
    var meaning: String?
    var context: String?
    var sourceVideoId: UUID?
    var sourceTimestamp: TimeInterval?
    var createdAt: Date

    // SM-2 algorithm fields
    var repetitions: Int
    var easinessFactor: Double
    var interval: Int
    var nextReviewDate: Date
    var lastReviewDate: Date?

    init(
        id: UUID = UUID(),
        word: String,
        meaning: String? = nil,
        context: String? = nil,
        sourceVideoId: UUID? = nil,
        sourceTimestamp: TimeInterval? = nil,
        createdAt: Date = Date(),
        repetitions: Int = 0,
        easinessFactor: Double = 2.5,
        interval: Int = 0,
        nextReviewDate: Date = Date(),
        lastReviewDate: Date? = nil
    ) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.context = context
        self.sourceVideoId = sourceVideoId
        self.sourceTimestamp = sourceTimestamp
        self.createdAt = createdAt
        self.repetitions = repetitions
        self.easinessFactor = easinessFactor
        self.interval = interval
        self.nextReviewDate = nextReviewDate
        self.lastReviewDate = lastReviewDate
    }
}
