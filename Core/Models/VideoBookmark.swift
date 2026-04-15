import Foundation

struct VideoBookmark: Identifiable {
    let id: UUID
    let videoId: UUID
    let timestamp: TimeInterval
    var note: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        videoId: UUID,
        timestamp: TimeInterval,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.videoId = videoId
        self.timestamp = timestamp
        self.note = note
        self.createdAt = createdAt
    }
}
