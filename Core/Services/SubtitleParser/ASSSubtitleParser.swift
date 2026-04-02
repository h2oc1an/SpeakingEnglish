import Foundation

class ASSSubtitleParser: SubtitleParserProtocol {

    func parse(fileURL: URL) throws -> [SubtitleEntry] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parse(content: content)
    }

    func parse(content: String) throws -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []

        // Find [Events] section
        let lines = content.components(separatedBy: "\n")
        var inEventsSection = false
        var formatColumns: [String] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.lowercased() == "[events]" {
                inEventsSection = true
                continue
            }

            if trimmedLine.lowercased().hasPrefix("[") && trimmedLine.hasSuffix("]") {
                inEventsSection = false
                continue
            }

            if inEventsSection {
                // Parse Format line
                if trimmedLine.lowercased().hasPrefix("format:") {
                    let formatContent = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    formatColumns = formatContent.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                    continue
                }

                // Parse Dialogue line
                if trimmedLine.lowercased().hasPrefix("dialogue:") {
                    if let entry = parseDialogueLine(trimmedLine, formatColumns: formatColumns, index: entries.count + 1) {
                        entries.append(entry)
                    }
                }
            }
        }

        return entries.sorted { $0.startTime < $1.startTime }
    }

    private func parseDialogueLine(_ line: String, formatColumns: [String], index: Int) -> SubtitleEntry? {
        // Format: Dialogue: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text
        let content = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)

        // Split by comma, but text field can contain commas
        var parts: [String] = []
        var currentPart = ""
        var commaCount = 0
        let textColumnIndex = formatColumns.firstIndex(of: "text") ?? 9

        for char in content {
            if char == "," && commaCount < textColumnIndex {
                parts.append(currentPart.trimmingCharacters(in: .whitespaces))
                currentPart = ""
                commaCount += 1
            } else {
                currentPart.append(char)
            }
        }
        parts.append(currentPart.trimmingCharacters(in: .whitespaces))

        guard parts.count >= 10 else { return nil }

        // Find Start and End columns
        guard let startIndex = formatColumns.firstIndex(of: "start"),
              let endIndex = formatColumns.firstIndex(of: "end"),
              startIndex < parts.count,
              endIndex < parts.count else {
            return nil
        }

        let startString = parts[startIndex]
        let endString = parts[endIndex]

        guard let startTime = parseTime(startString),
              let endTime = parseTime(endString) else {
            return nil
        }

        // Text is the last part (after last comma)
        let text = parts.last ?? ""
        let cleanedText = cleanASSMarkup(text)

        return SubtitleEntry(
            index: index,
            startTime: startTime,
            endTime: endTime,
            text: cleanedText
        )
    }

    private func parseTime(_ timeString: String) -> TimeInterval? {
        // Format: "H:MM:SS.cc" (centiseconds) or "H:MM:SS.mmm" (milliseconds)
        let parts = timeString.components(separatedBy: ":")
        guard parts.count == 3 else { return nil }

        guard let hours = Double(parts[0]),
              let minutes = Double(parts[1]) else {
            return nil
        }

        // Seconds part may have centiseconds or milliseconds
        let secondsPart = parts[2]
        let secondsComponents = secondsPart.components(separatedBy: ".")

        guard let seconds = Double(secondsComponents[0]) else {
            return nil
        }

        var milliseconds: Double = 0
        if secondsComponents.count >= 2 {
            let fractionString = secondsComponents[1]
            // Handle both .cc (centiseconds) and .mmm (milliseconds)
            if fractionString.count == 2 {
                // Centiseconds
                milliseconds = (Double(fractionString) ?? 0) / 100
            } else if fractionString.count == 3 {
                // Milliseconds
                milliseconds = (Double(fractionString) ?? 0) / 1000
            }
        }

        return hours * 3600 + minutes * 60 + seconds + milliseconds
    }

    private func cleanASSMarkup(_ text: String) -> String {
        var result = text

        // Remove common ASS tags
        // {\an8} - alignment
        // {\pos(x,y)} - position
        // {\move(x1,y1,x2,y2)} - movement
        // {\fad(a1,a2)} - fade
        // {\fade(a1,a2,a3,a4)} - fade
        // {\blur#} - blur
        // {\be#} - blur edge

        // Remove {\...} patterns
        let tagPattern = "\\{[^}]*\\}"
        result = result.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)

        // Replace \N and \n with newlines
        result = result.replacingOccurrences(of: "\\N", with: "\n")
        result = result.replacingOccurrences(of: "\\n", with: "\n")

        // Replace \h with non-breaking space
        result = result.replacingOccurrences(of: "\\h", with: " ")

        // Replace \t with nothing (skip)
        result = result.replacingOccurrences(of: "\\t", with: "")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
