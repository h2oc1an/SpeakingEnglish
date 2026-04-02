import Foundation
import SQLite

protocol VocabularyRepositoryProtocol {
    func save(_ entry: VocabularyEntry) throws
    func getAll() throws -> [VocabularyEntry]
    func getById(_ id: UUID) throws -> VocabularyEntry?
    func getDueForReview() throws -> [VocabularyEntry]
    func update(_ entry: VocabularyEntry) throws
    func delete(_ id: UUID) throws
    func search(_ keyword: String) throws -> [VocabularyEntry]
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

    func getAll() throws -> [VocabularyEntry] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        var entries: [VocabularyEntry] = []
        for row in try db.prepare(manager.vocabularyEntries.order(manager.vocabCreatedAt.desc)) {
            let entry = VocabularyEntry(
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
            entries.append(entry)
        }
        return entries
    }

    func getById(_ id: UUID) throws -> VocabularyEntry? {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.vocabularyEntries.filter(manager.vocabId == id.uuidString)
        guard let row = try db.pluck(query) else { return nil }

        return VocabularyEntry(
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

    func getDueForReview() throws -> [VocabularyEntry] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let now = DatabaseManager.dateToString(Date())
        let query = manager.vocabularyEntries
            .filter(manager.vocabNextReviewDate <= now)
            .order(manager.vocabNextReviewDate.asc)

        var entries: [VocabularyEntry] = []
        for row in try db.prepare(query) {
            let entry = VocabularyEntry(
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
            entries.append(entry)
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

    func search(_ keyword: String) throws -> [VocabularyEntry] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.vocabularyEntries
            .filter(manager.vocabWord.like("%\(keyword)%"))
            .order(manager.vocabCreatedAt.desc)

        var entries: [VocabularyEntry] = []
        for row in try db.prepare(query) {
            let entry = VocabularyEntry(
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
            entries.append(entry)
        }
        return entries
    }
}
