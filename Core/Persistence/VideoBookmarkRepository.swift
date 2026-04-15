import Foundation
import SQLite

class VideoBookmarkRepository {
    private let db: Connection?
    private let manager = DatabaseManager.shared

    init() {
        self.db = manager.getConnection()
    }

    func save(_ bookmark: VideoBookmark) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let insert = manager.videoBookmarks.insert(
            manager.bookmarkId <- bookmark.id.uuidString,
            manager.bookmarkVideoId <- bookmark.videoId.uuidString,
            manager.bookmarkTimestamp <- bookmark.timestamp,
            manager.bookmarkNote <- bookmark.note,
            manager.bookmarkCreatedAt <- DatabaseManager.dateToString(bookmark.createdAt)
        )

        try db.run(insert)
    }

    func getAll(for videoId: UUID) throws -> [VideoBookmark] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        var bookmarks: [VideoBookmark] = []
        let query = manager.videoBookmarks
            .filter(manager.bookmarkVideoId == videoId.uuidString)
            .order(manager.bookmarkTimestamp)

        for row in try db.prepare(query) {
            let bookmark = VideoBookmark(
                id: UUID(uuidString: row[manager.bookmarkId])!,
                videoId: UUID(uuidString: row[manager.bookmarkVideoId])!,
                timestamp: row[manager.bookmarkTimestamp],
                note: row[manager.bookmarkNote],
                createdAt: DatabaseManager.stringToDate(row[manager.bookmarkCreatedAt])
            )
            bookmarks.append(bookmark)
        }
        return bookmarks
    }

    func delete(_ id: UUID) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.videoBookmarks.filter(manager.bookmarkId == id.uuidString)
        try db.run(query.delete())
    }

    func update(_ bookmark: VideoBookmark) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.videoBookmarks.filter(manager.bookmarkId == bookmark.id.uuidString)
        try db.run(query.update(
            manager.bookmarkNote <- bookmark.note
        ))
    }
}
