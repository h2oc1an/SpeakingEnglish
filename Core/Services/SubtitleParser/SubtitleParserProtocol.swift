import Foundation

protocol SubtitleParserProtocol {
    func parse(fileURL: URL) throws -> [SubtitleEntry]
    func parse(content: String) throws -> [SubtitleEntry]
}
