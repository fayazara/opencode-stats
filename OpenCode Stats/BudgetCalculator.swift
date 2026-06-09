import Foundation

struct BudgetCalculator {
    let dailyBudget: Double
    let monthlyBudget: Double
    let todayCost: Double
    let monthlyCost: Double

    enum Level: Comparable {
        case none
        case approaching(ratio: Double)
        case exceeded(ratio: Double)

        var ratio: Double {
            switch self {
            case .none: return 0
            case .approaching(let r): return r
            case .exceeded(let r): return r
            }
        }

        var isExceeded: Bool {
            if case .exceeded = self { return true }
            return false
        }

        var isApproaching: Bool {
            if case .approaching = self { return true }
            return false
        }

        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.ratio < rhs.ratio
        }
    }

    var dailyRatio: Double {
        dailyBudget > 0 ? todayCost / dailyBudget : 0
    }

    var monthlyRatio: Double {
        monthlyBudget > 0 ? monthlyCost / monthlyBudget : 0
    }

    var dailyLevel: Level {
        level(for: dailyRatio)
    }

    var monthlyLevel: Level {
        level(for: monthlyRatio)
    }

    var overallLevel: Level {
        max(dailyLevel, monthlyLevel)
    }

    private func level(for ratio: Double) -> Level {
        if ratio >= 1.0 {
            return .exceeded(ratio: ratio)
        } else if ratio >= 0.8 {
            return .approaching(ratio: ratio)
        }
        return .none
    }
}
