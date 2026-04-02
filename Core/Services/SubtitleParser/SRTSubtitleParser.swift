import Foundation

class SRTSubtitleParser: SubtitleParserProtocol {

    func parse(fileURL: URL) throws -> [SubtitleEntry] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parse(content: content)
    }

    func parse(content: String) throws -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []

        // Split by empty lines to get subtitle blocks
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBlock.isEmpty { continue }

            let lines = trimmedBlock.components(separatedBy: "\n")
            guard lines.count >= 2 else { continue }

            // First line: index number
            guard let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else { continue }

            // Second line: time format "HH:MM:SS,mmm --> HH:MM:SS,mmm"
            let timeLine = lines[1]
            guard let times = parseTimeLine(timeLine) else { continue }

            // Remaining lines: subtitle text
            let textLines = Array(lines[2...])
            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            let entry = SubtitleEntry(
                index: index,
                startTime: times.start,
                endTime: times.end,
                text: text
            )
            entries.append(entry)
        }

        return entries.sorted { $0.startTime < $1.startTime }
    }

    private func parseTimeLine(_ line: String) -> (start: TimeInterval, end: TimeInterval)? {
        // Format: "HH:MM:SS,mmm --> HH:MM:SS,mmm"
        let components = line.components(separatedBy: "-->")
        guard components.count == 2 else { return nil }

        let startString = components[0].trimmingCharacters(in: .whitespaces)
        let endString = components[1].trimmingCharacters(in: .whitespaces)

        guard let startTime = parseTime(startString),
              let endTime = parseTime(endString) else {
            return nil
        }

        return (startTime, endTime)
    }

    private func parseTime(_ timeString: String) -> TimeInterval? {
        // Format: "HH:MM:SS,mmm"
        // Replace comma with dot for consistent parsing
        let normalized = timeString.replacingOccurrences(of: ",", with: ".")

        let parts = normalized.components(separatedBy: ":")
        guard parts.count == 3 else { return nil }

        guard let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return nil
        }

        return hours * 3600 + minutes * 60 + seconds
    }
}
