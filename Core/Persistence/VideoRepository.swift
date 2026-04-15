import Foundation
import SQLite

protocol VideoRepositoryProtocol {
    func save(_ video: Video) throws
    func getAll() throws -> [Video]
    func getById(_ id: UUID) throws -> Video?
    func update(_ video: Video) throws
    func delete(_ id: UUID) throws
}

class VideoRepository: VideoRepositoryProtocol {
    static let shared = VideoRepository()
    private let db: Connection?
    private let manager = DatabaseManager.shared

    init() {
        self.db = manager.getConnection()
    }

    func save(_ video: Video) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let insert = manager.videos.insert(
            manager.videoId <- video.id.uuidString,
            manager.videoTitle <- video.title,
            manager.videoLocalPath <- video.localPath,
            manager.videoThumbnailPath <- video.thumbnailPath,
            manager.videoDuration <- video.duration,
            manager.videoSubtitlePath <- video.subtitlePath,
            manager.videoCreatedAt <- DatabaseManager.dateToString(video.createdAt),
            manager.videoLastPlayedAt <- video.lastPlayedAt.map { DatabaseManager.dateToString($0) }
        )

        try db.run(insert)
    }

    func getAll() throws -> [Video] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        var videos: [Video] = []
        for row in try db.prepare(manager.videos) {
            let video = Video(
                id: UUID(uuidString: row[manager.videoId])!,
                title: row[manager.videoTitle],
                localPath: row[manager.videoLocalPath],
                thumbnailPath: row[manager.videoThumbnailPath],
                duration: row[manager.videoDuration],
                subtitlePath: row[manager.videoSubtitlePath],
                createdAt: DatabaseManager.stringToDate(row[manager.videoCreatedAt]),
                lastPlayedAt: row[manager.videoLastPlayedAt].map { DatabaseManager.stringToDate($0) }
            )
            videos.append(video)
        }
        return videos
    }

    func getById(_ id: UUID) throws -> Video? {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.videos.filter(manager.videoId == id.uuidString)
        guard let row = try db.pluck(query) else { return nil }

        return Video(
            id: UUID(uuidString: row[manager.videoId])!,
            title: row[manager.videoTitle],
            localPath: row[manager.videoLocalPath],
            thumbnailPath: row[manager.videoThumbnailPath],
            duration: row[manager.videoDuration],
            subtitlePath: row[manager.videoSubtitlePath],
            createdAt: DatabaseManager.stringToDate(row[manager.videoCreatedAt]),
            lastPlayedAt: row[manager.videoLastPlayedAt].map { DatabaseManager.stringToDate($0) }
        )
    }

    func update(_ video: Video) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.videos.filter(manager.videoId == video.id.uuidString)
        try db.run(query.update(
            manager.videoTitle <- video.title,
            manager.videoLocalPath <- video.localPath,
            manager.videoThumbnailPath <- video.thumbnailPath,
            manager.videoDuration <- video.duration,
            manager.videoSubtitlePath <- video.subtitlePath,
            manager.videoLastPlayedAt <- video.lastPlayedAt.map { DatabaseManager.dateToString($0) }
        ))
    }

    func delete(_ id: UUID) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.videos.filter(manager.videoId == id.uuidString)
        try db.run(query.delete())
    }

    // MARK: - Playback Position & Rate

    func getLastPlaybackPosition(for videoId: UUID) -> Double {
        guard let db = db else { return 0 }
        let query = manager.videos.filter(manager.videoId == videoId.uuidString)
        guard let row = try? db.pluck(query) else { return 0 }
        return row[manager.videoLastPlaybackPosition]
    }

    func saveLastPlaybackPosition(for videoId: UUID, position: Double) {
        guard let db = db else { return }
        let query = manager.videos.filter(manager.videoId == videoId.uuidString)
        try? db.run(query.update(manager.videoLastPlaybackPosition <- position))
    }

    func getPlaybackRate(for videoId: UUID) -> Float? {
        guard let db = db else { return nil }
        let query = manager.videos.filter(manager.videoId == videoId.uuidString)
        guard let row = try? db.pluck(query) else { return nil }
        let rate = row[manager.videoPlaybackRate]
        return Float(rate)
    }

    func savePlaybackRate(for videoId: UUID, rate: Float) {
        guard let db = db else { return }
        let query = manager.videos.filter(manager.videoId == videoId.uuidString)
        try? db.run(query.update(manager.videoPlaybackRate <- Double(rate)))
    }
}

enum RepositoryError: Error {
    case connectionFailed
    case notFound
    case saveFailed
}
