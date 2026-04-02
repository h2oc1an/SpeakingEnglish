import Foundation

struct Video: Identifiable, Codable {
    let id: UUID
    var title: String
    var localPath: String
    var thumbnailPath: String?
    var duration: TimeInterval
    var subtitlePath: String?
    var createdAt: Date
    var lastPlayedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        localPath: String,
        thumbnailPath: String? = nil,
        duration: TimeInterval = 0,
        subtitlePath: String? = nil,
        createdAt: Date = Date(),
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.duration = duration
        self.subtitlePath = subtitlePath
        self.createdAt = createdAt
        self.lastPlayedAt = lastPlayedAt
    }
}
