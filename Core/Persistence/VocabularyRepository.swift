import Foundation
import SQLite

protocol VocabularyRepositoryProtocol {
    func save(_ entry: VocabularyEntry) throws
    func getAll(limit: Int?, offset: Int?) throws -> [VocabularyEntry]
    func getById(_ id: UUID) throws -> VocabularyEntry?
    func getDueForReview(limit: Int?, offset: Int?) throws -> [VocabularyEntry]
    func update(_ entry: VocabularyEntry) throws
    func delete(_ id: UUID) throws
    func search(_ keyword: String, limit: Int?, offset: Int?) throws -> [VocabularyEntry]
    func getTotalCount() throws -> Int
    func getDueCount() throws -> Int
}

class VocabularyRepository: VocabularyRepositoryProtocol {
    private let db: Connection?
    private let manager = DatabaseManager.shared

    init() {
        self.db = manager.getConnection()
    }

    func save(_ entry: VocabularyEntry) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let insert = manager.vocabularyEntries.insert(
            manager.vocabId <- entry.id.uuidString,
            manager.vocabWord <- entry.word,
            manager.vocabMeaning <- entry.meaning,
            manager.vocabContext <- entry.context,
            manager.vocabSourceVideoId <- entry.sourceVideoId?.uuidString,
            manager.vocabSourceTimestamp <- entry.sourceTimestamp,
            manager.vocabCreatedAt <- DatabaseManager.dateToString(entry.createdAt),
            manager.vocabRepetitions <- entry.repetitions,
            manager.vocabEasinessFactor <- entry.easinessFactor,
            manager.vocabInterval <- entry.interval,
            manager.vocabNextReviewDate <- DatabaseManager.dateToString(entry.nextReviewDate),
            manager.vocabLastReviewDate <- entry.lastReviewDate.map { DatabaseManager.dateToString($0) }
        )

        try db.run(insert)
    }

    func getAll(limit: Int? = nil, offset: Int? = nil) throws -> [VocabularyEntry] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        var entries: [VocabularyEntry] = []
        if let limitValue = limit {
            let offsetValue = offset ?? 0
            let query = manager.vocabularyEntries.order(manager.vocabCreatedAt.desc).limit(limitValue, offset: offsetValue)
            for row in try db.prepare(query) {
                entries.append(rowToEntry(row))
            }
        } else {
            let query = manager.vocabularyEntries.order(manager.vocabCreatedAt.desc)
            for row in try db.prepare(query) {
                entries.append(rowToEntry(row))
            }
        }
        return entries
    }

    func getById(_ id: UUID) throws -> VocabularyEntry? {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.vocabularyEntries.filter(manager.vocabId == id.uuidString)
        guard let row = try db.pluck(query) else { return nil }

        return rowToEntry(row)
    }

    func getDueForReview(limit: Int? = nil, offset: Int? = nil) throws -> [VocabularyEntry] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let now = DatabaseManager.dateToString(Date())
        var entries: [VocabularyEntry] = []

        if let limitValue = limit {
            let offsetValue = offset ?? 0
            let query = manager.vocabularyEntries
                .filter(manager.vocabNextReviewDate <= now)
                .order(manager.vocabNextReviewDate.asc)
                .limit(limitValue, offset: offsetValue)
            for row in try db.prepare(query) {
                entries.append(rowToEntry(row))
            }
        } else {
            let query = manager.vocabularyEntries
                .filter(manager.vocabNextReviewDate <= now)
                .order(manager.vocabNextReviewDate.asc)
            for row in try db.prepare(query) {
                entries.append(rowToEntry(row))
            }
        }
        return entries
    }

    func update(_ entry: VocabularyEntry) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.vocabularyEntries.filter(manager.vocabId == entry.id.uuidString)
        try db.run(query.update(
            manager.vocabWord <- entry.word,
            manager.vocabMeaning <- entry.meaning,
            manager.vocabContext <- entry.context,
            manager.vocabRepetitions <- entry.repetitions,
            manager.vocabEasinessFactor <- entry.easinessFactor,
            manager.vocabInterval <- entry.interval,
            manager.vocabNextReviewDate <- DatabaseManager.dateToString(entry.nextReviewDate),
            manager.vocabLastReviewDate <- entry.lastReviewDate.map { DatabaseManager.dateToString($0) }
        ))
    }

    func delete(_ id: UUID) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.vocabularyEntries.filter(manager.vocabId == id.uuidString)
        try db.run(query.delete())
    }

    func search(_ keyword: String, limit: Int? = nil, offset: Int? = nil) throws -> [VocabularyEntry] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        // Use lower() for case-insensitive search without leading wildcard
        let query = manager.vocabularyEntries
            .filter(manager.vocabWord.lowercaseString.like("%\(keyword.lowercased())%"))
            .order(manager.vocabCreatedAt.desc)

        var entries: [VocabularyEntry] = []
        var rowCount = 0
        for row in try db.prepare(query) {
            if let offsetVal = offset, rowCount < offsetVal {
                rowCount += 1
                continue
            }
            if let limitVal = limit, entries.count >= limitVal {
                break
            }
            entries.append(rowToEntry(row))
            rowCount += 1
        }
        return entries
    }

    func getTotalCount() throws -> Int {
        guard let db = db else { throw RepositoryError.connectionFailed }
        return try db.scalar(manager.vocabularyEntries.count)
    }

    func getDueCount() throws -> Int {
        guard let db = db else { throw RepositoryError.connectionFailed }
        let now = DatabaseManager.dateToString(Date())
        return try db.scalar(manager.vocabularyEntries.filter(manager.vocabNextReviewDate <= now).count)
    }

    // MARK: - Helper

    private func rowToEntry(_ row: Row) -> VocabularyEntry {
        VocabularyEntry(
            id: UUID(uuidString: row[manager.vocabId])!,
            word: row[manager.vocabWord],
            meaning: row[manager.vocabMeaning],
            context: row[manager.vocabContext],
            sourceVideoId: row[manager.vocabSourceVideoId].flatMap { UUID(uuidString: $0) },
            sourceTimestamp: row[manager.vocabSourceTimestamp],
            createdAt: DatabaseManager.stringToDate(row[manager.vocabCreatedAt]),
            repetitions: row[manager.vocabRepetitions],
            easinessFactor: row[manager.vocabEasinessFactor],
            interval: row[manager.vocabInterval],
            nextReviewDate: DatabaseManager.stringToDate(row[manager.vocabNextReviewDate]),
            lastReviewDate: row[manager.vocabLastReviewDate].map { DatabaseManager.stringToDate($0) }
        )
    }
}
