import Foundation

struct Word: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var startTime: TimeInterval?
    var subtitleEntryId: UUID?

    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval? = nil,
        subtitleEntryId: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.subtitleEntryId = subtitleEntryId
    }
}
