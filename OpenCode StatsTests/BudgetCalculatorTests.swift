import XCTest
@testable import OpenCode_Stats

final class BudgetCalculatorTests: XCTestCase {

    private let zero = 0.0

    // MARK: - No budget set (zero budgets)

    func test_zeroBudgets_returnsNone() {
        let sut = BudgetCalculator(dailyBudget: 0, monthlyBudget: 0, todayCost: 100, monthlyCost: 500)
        XCTAssertEqual(sut.overallLevel, .none)
        XCTAssertEqual(sut.dailyLevel, .none)
        XCTAssertEqual(sut.monthlyLevel, .none)
        XCTAssertEqual(sut.dailyRatio, 0)
        XCTAssertEqual(sut.monthlyRatio, 0)
    }

    // MARK: - Daily budget

    func test_dailyBudget_notYetApproaching() {
        let sut = BudgetCalculator(dailyBudget: 100, monthlyBudget: 0, todayCost: 50, monthlyCost: 0)
        XCTAssertEqual(sut.dailyLevel, .none)
        XCTAssertEqual(sut.dailyRatio, 0.5, accuracy: 0.001)
        XCTAssertEqual(sut.overallLevel, .none)
    }

    func test_dailyBudget_approaching() {
        let sut = BudgetCalculator(dailyBudget: 100, monthlyBudget: 0, todayCost: 85, monthlyCost: 0)
        XCTAssertEqual(sut.dailyLevel, .approaching(ratio: 0.85))
        XCTAssertEqual(sut.dailyRatio, 0.85, accuracy: 0.001)
        XCTAssertEqual(sut.overallLevel, .approaching(ratio: 0.85))
    }

    func test_dailyBudget_atExactThreshold_approaching() {
        let sut = BudgetCalculator(dailyBudget: 100, monthlyBudget: 0, todayCost: 80, monthlyCost: 0)
        XCTAssertEqual(sut.dailyLevel, .approaching(ratio: 0.8))
    }

    func test_dailyBudget_exceeded() {
        let sut = BudgetCalculator(dailyBudget: 100, monthlyBudget: 0, todayCost: 120, monthlyCost: 0)
        XCTAssertEqual(sut.dailyLevel, .exceeded(ratio: 1.2))
        XCTAssertTrue(sut.dailyLevel.isExceeded)
        XCTAssertFalse(sut.dailyLevel.isApproaching)
        XCTAssertEqual(sut.overallLevel, .exceeded(ratio: 1.2))
    }

    func test_dailyBudget_atExactExceeded() {
        let sut = BudgetCalculator(dailyBudget: 50, monthlyBudget: 0, todayCost: 50, monthlyCost: 0)
        XCTAssertEqual(sut.dailyLevel, .exceeded(ratio: 1.0))
        XCTAssertTrue(sut.dailyLevel.isExceeded)
    }

    // MARK: - Monthly budget

    func test_monthlyBudget_notYetApproaching() {
        let sut = BudgetCalculator(dailyBudget: 0, monthlyBudget: 1000, todayCost: 0, monthlyCost: 400)
        XCTAssertEqual(sut.monthlyLevel, .none)
        XCTAssertEqual(sut.monthlyRatio, 0.4, accuracy: 0.001)
    }

    func test_monthlyBudget_approaching() {
        let sut = BudgetCalculator(dailyBudget: 0, monthlyBudget: 1000, todayCost: 0, monthlyCost: 850)
        XCTAssertEqual(sut.monthlyLevel, .approaching(ratio: 0.85))
    }

    func test_monthlyBudget_exceeded() {
        let sut = BudgetCalculator(dailyBudget: 0, monthlyBudget: 1000, todayCost: 0, monthlyCost: 1500)
        XCTAssertEqual(sut.monthlyLevel, .exceeded(ratio: 1.5))
    }

    // MARK: - Combined (daily + monthly)

    func test_dailyApproaching_monthlyExceeded_overallIsExceeded() {
        let sut = BudgetCalculator(dailyBudget: 100, monthlyBudget: 1000, todayCost: 85, monthlyCost: 1200)
        XCTAssertEqual(sut.dailyLevel, .approaching(ratio: 0.85))
        XCTAssertEqual(sut.monthlyLevel, .exceeded(ratio: 1.2))
        XCTAssertEqual(sut.overallLevel, .exceeded(ratio: 1.2))
    }

    func test_dailyExceeded_monthlyNone_overallIsExceeded() {
        let sut = BudgetCalculator(dailyBudget: 50, monthlyBudget: 2000, todayCost: 60, monthlyCost: 500)
        XCTAssertEqual(sut.dailyLevel, .exceeded(ratio: 1.2))
        XCTAssertEqual(sut.monthlyLevel, .none)
        XCTAssertEqual(sut.overallLevel, .exceeded(ratio: 1.2))
    }

    func test_dailyZeroBudget_onlyMonthlyEvaluated() {
        let sut = BudgetCalculator(dailyBudget: 0, monthlyBudget: 500, todayCost: 999, monthlyCost: 450)
        XCTAssertEqual(sut.dailyRatio, 0)
        XCTAssertEqual(sut.dailyLevel, .none)
        XCTAssertEqual(sut.monthlyLevel, .approaching(ratio: 0.9))
        XCTAssertEqual(sut.overallLevel, .approaching(ratio: 0.9))
    }

    // MARK: - Edge cases

    func test_todayCostZero_withBudget() {
        let sut = BudgetCalculator(dailyBudget: 100, monthlyBudget: 500, todayCost: 0, monthlyCost: 0)
        XCTAssertEqual(sut.dailyRatio, 0)
        XCTAssertEqual(sut.dailyLevel, .none)
        XCTAssertEqual(sut.monthlyLevel, .none)
    }

    func test_negativeCosts_treatedAsLargerThanBudget() {
        let sut = BudgetCalculator(dailyBudget: 100, monthlyBudget: 500, todayCost: -10, monthlyCost: -50)
        XCTAssertEqual(sut.dailyRatio, -0.1, accuracy: 0.001)
        XCTAssertEqual(sut.dailyLevel, .none)
        XCTAssertEqual(sut.monthlyLevel, .none)
    }

    func test_negativeBudget_notUsedForCalculation() {
        let sut = BudgetCalculator(dailyBudget: -50, monthlyBudget: 0, todayCost: 100, monthlyCost: 0)
        XCTAssertEqual(sut.dailyRatio, 0)
        XCTAssertEqual(sut.dailyLevel, .none)
    }

    // MARK: - Level properties

    func test_level_isExceeded() {
        XCTAssertTrue(BudgetCalculator.Level.exceeded(ratio: 1.5).isExceeded)
        XCTAssertFalse(BudgetCalculator.Level.approaching(ratio: 0.9).isExceeded)
        XCTAssertFalse(BudgetCalculator.Level.none.isExceeded)
    }

    func test_level_isApproaching() {
        XCTAssertTrue(BudgetCalculator.Level.approaching(ratio: 0.9).isApproaching)
        XCTAssertFalse(BudgetCalculator.Level.exceeded(ratio: 1.5).isApproaching)
        XCTAssertFalse(BudgetCalculator.Level.none.isApproaching)
    }

    func test_level_ratio() {
        XCTAssertEqual(BudgetCalculator.Level.none.ratio, 0)
        XCTAssertEqual(BudgetCalculator.Level.approaching(ratio: 0.85).ratio, 0.85, accuracy: 0.001)
        XCTAssertEqual(BudgetCalculator.Level.exceeded(ratio: 1.2).ratio, 1.2, accuracy: 0.001)
    }

    func test_level_comparable() {
        let exceeded = BudgetCalculator.Level.exceeded(ratio: 1.5)
        let approaching = BudgetCalculator.Level.approaching(ratio: 0.9)
        let none = BudgetCalculator.Level.none
        XCTAssertGreaterThan(exceeded, approaching)
        XCTAssertGreaterThan(approaching, none)
        XCTAssertGreaterThan(exceeded, none)
    }
}
