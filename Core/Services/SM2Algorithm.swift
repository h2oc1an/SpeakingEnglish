import Foundation

struct SM2Algorithm {

    struct ReviewResult {
        var repetitions: Int
        var easinessFactor: Double
        var interval: Int
        var nextReviewDate: Date
    }

    /// SM-2 算法参数
    private enum Config {
        /// EF 最小值，防止难度过低
        static let minEasinessFactor: Double = 1.3
        /// EF 调整基数
        static let efBase: Double = 0.1
        /// EF 调整系数
        static let efModifier: Double = 0.08
        /// EF 二次调整系数
        static let efModifierSquared: Double = 0.02
        /// 首次间隔（天）
        static let firstInterval = 1
        /// 第二次间隔（天）
        static let secondInterval = 6
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

        // 计算新的 EF（easiness factor）
        // EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
        // 答得越差，EF 下降越多
        let efDelta = Config.efBase - Double(5 - q) * (Config.efModifier + Double(5 - q) * Config.efModifierSquared)
        var newEF = easinessFactor + efDelta
        // EF 不能低于 1.3
        newEF = max(Config.minEasinessFactor, newEF)

        var newRepetitions: Int
        var newInterval: Int

        if q < 3 {
            // 如果答得不好（质量 < 3），重新开始
            newRepetitions = 0
            newInterval = Config.firstInterval
        } else {
            newRepetitions = repetitions + 1
            switch newRepetitions {
            case 1:
                newInterval = Config.firstInterval
            case 2:
                newInterval = Config.secondInterval
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

    /// 简化的质量评级（对应 UI 按钮）
    enum Quality: Int, CaseIterable {
        case forgotten = 0      // 完全忘记
        case hard = 1         // 困难，想了一下才想起来
        case difficult = 2     // 较难，看答案后才想起来
        case good = 3          // 一般，想起来了
        case easy = 4          // 简单，有点犹豫
        case perfect = 5       // 完美，立刻想起来

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

        /// 颜色 HEX 值
        var color: String {
            switch self {
            case .forgotten: return "FF3B30"  // 红色 - 危险
            case .hard: return "FF9500"       // 橙色 - 警告
            case .difficult: return "FFCC00"  // 黄色 - 注意
            case .good: return "34C759"        // 绿色 - 良好
            case .easy: return "34C759"        // 绿色 - 良好
            case .perfect: return "007AFF"      // 蓝色 - 优秀
            }
        }
    }
}
