import Foundation

/// 双语字幕解析工具
struct BilingualTextParser {
    /// 分隔符列表
    private static let separators = [" - ", " / ", "｜", " | ", "\n"]

    /// 解析双语字幕文本，返回 (英文, 中文)
    static func parse(_ text: String) -> (String, String) {
        // 先尝试用分隔符分割
        for separator in separators {
            if let range = text.range(of: separator) {
                let part1 = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let part2 = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !part1.isEmpty && !part2.isEmpty {
                    if containsChinese(part2) {
                        return (part1, part2)
                    } else if containsChinese(part1) {
                        return (part2, part1)
                    }
                }
            }
        }

        // 如果没有分隔符但包含中文，用字符位置分割
        if containsChinese(text) {
            return extractEnglishAndChinese(from: text)
        }

        return (text, "")
    }

    /// 判断文本是否包含中文
    static func containsChinese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }

    /// 从混合文本中提取英文和中文
    private static func extractEnglishAndChinese(from text: String) -> (String, String) {
        var chineseStartIndex: String.Index?
        for (index, char) in text.enumerated() {
            let scalar = char.unicodeScalars.first!
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                chineseStartIndex = text.index(text.startIndex, offsetBy: index)
                break
            }
        }
        if let chineseIndex = chineseStartIndex {
            let englishPart = String(text[..<chineseIndex]).trimmingCharacters(in: .whitespaces)
            let chinesePart = String(text[chineseIndex...]).trimmingCharacters(in: .whitespaces)
            return (englishPart, chinesePart)
        }
        return (text, "")
    }
}
