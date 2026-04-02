import Foundation

struct ReviewRecord: Identifiable, Codable {
    let id: UUID
    var vocabularyEntryId: UUID
    var reviewDate: Date
    var quality: Int
    var repetition: Int
    var easinessFactor: Double
    var interval: Int

    init(
        id: UUID = UUID(),
        vocabularyEntryId: UUID,
        reviewDate: Date = Date(),
        quality: Int,
        repetition: Int,
        easinessFactor: Double,
        interval: Int
    ) {
        self.id = id
        self.vocabularyEntryId = vocabularyEntryId
        self.reviewDate = reviewDate
        self.quality = quality
        self.repetition = repetition
        self.easinessFactor = easinessFactor
        self.interval = interval
    }
}
