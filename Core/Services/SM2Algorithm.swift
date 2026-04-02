import Foundation

struct SM2Algorithm {

    struct ReviewResult {
        var repetitions: Int
        var easinessFactor: Double
        var interval: Int
        var nextReviewDate: Date
    }

    /// Quality ratings:
    /// 0 - Complete blackout, no recognition
    /// 1 - Incorrect response, but remembered upon seeing answer
    /// 2 - Incorrect response, but easily remembered after seeing answer
    /// 3 - Correct response with significant difficulty
    /// 4 - Correct response with some hesitation
    /// 5 - Perfect response with no hesitation
    static func calculate(
        quality: Int,
        repetitions: Int,
        easinessFactor: Double,
        interval: Int
    ) -> ReviewResult {
        // Clamp quality to valid range
        let q = max(0, min(5, quality))

        // Calculate new easiness factor
        var newEF = easinessFactor + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02))
        newEF = max(1.3, newEF) // EF should never fall below 1.3

        var newRepetitions: Int
        var newInterval: Int

        if q < 3 {
            // If response quality is less than 3, reset repetitions
            newRepetitions = 0
            newInterval = 1
        } else {
            newRepetitions = repetitions + 1
            switch newRepetitions {
            case 1:
                newInterval = 1
            case 2:
                newInterval = 6
            default:
                newInterval = Int(Double(interval) * newEF)
            }
        }

        let nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: newInterval,
            to: Date()
        ) ?? Date()

        return ReviewResult(
            repetitions: newRepetitions,
            easinessFactor: newEF,
            interval: newInterval,
            nextReviewDate: nextReviewDate
        )
    }

    /// Simplified quality mapping for UI
    enum Quality: Int, CaseIterable {
        case forgotten = 0      // Complete blackout
        case hard = 1           // Incorrect, remembered after
        case difficult = 2      // Incorrect, easily remembered
        case good = 3           // Correct with effort
        case easy = 4           // Correct with hesitation
        case perfect = 5        // Perfect recall

        var displayName: String {
            switch self {
            case .forgotten: return "忘记"
            case .hard: return "困难"
            case .difficult: return "较难"
            case .good: return "一般"
            case .easy: return "简单"
            case .perfect: return "完美"
            }
        }

        var color: String {
            switch self {
            case .forgotten: return "FF3B30" // Red
            case .hard: return "FF9500"      // Orange
            case .difficult: return "FFCC00" // Yellow
            case .good: return "34C759"      // Green
            case .easy: return "34C759"      // Green
            case .perfect: return "007AFF"    // Blue
            }
        }
    }
}
