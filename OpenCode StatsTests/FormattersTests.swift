import XCTest
@testable import OpenCode_Stats

final class FormattersTests: XCTestCase {

    // MARK: - Currency

    func test_currency_zero() {
        XCTAssertEqual(Formatters.currency(0), "$0.00")
    }

    func test_currency_small() {
        XCTAssertEqual(Formatters.currency(0.5), "$0.50")
    }

    func test_currency_whole() {
        XCTAssertEqual(Formatters.currency(42), "$42.00")
    }

    func test_currency_large() {
        XCTAssertEqual(Formatters.currency(1234.5678), "$1234.57")
    }

    func test_currency_negative() {
        XCTAssertEqual(Formatters.currency(-5), "$-5.00")
    }

    // MARK: - Tokens (Int64)

    func test_tokensInt64_zero() {
        XCTAssertEqual(Formatters.tokens(Int64(0)), "0")
    }

    func test_tokensInt64_underThousand() {
        XCTAssertEqual(Formatters.tokens(Int64(999)), "999")
    }

    func test_tokensInt64_thousands() {
        XCTAssertEqual(Formatters.tokens(Int64(1500)), "1.5K")
    }

    func test_tokensInt64_millions() {
        XCTAssertEqual(Formatters.tokens(Int64(2_500_000)), "2.5M")
    }

    func test_tokensInt64_billions() {
        XCTAssertEqual(Formatters.tokens(Int64(3_200_000_000)), "3.2B")
    }

    // MARK: - Tokens (Double)

    func test_tokensDouble_zero() {
        XCTAssertEqual(Formatters.tokens(0.0), "0")
    }

    func test_tokensDouble_thousands() {
        XCTAssertEqual(Formatters.tokens(7_500.0), "7.5K")
    }

    func test_tokensDouble_millions() {
        XCTAssertEqual(Formatters.tokens(1_000_000.0), "1.0M")
    }

    func test_tokensDouble_billions() {
        XCTAssertEqual(Formatters.tokens(1_500_000_000.0), "1.5B")
    }

    // MARK: - Number

    func test_number_zero() {
        XCTAssertEqual(Formatters.number(0), "0")
    }

    func test_number_small() {
        XCTAssertEqual(Formatters.number(42), "42")
    }

    func test_number_withThousands() {
        XCTAssertEqual(Formatters.number(1_234), "1,234")
    }

    func test_number_large() {
        XCTAssertEqual(Formatters.number(1_234_567), "1,234,567")
    }

    // MARK: - Percentage

    func test_percentage_small() {
        XCTAssertEqual(Formatters.percentage(5.3), "5.3%")
    }

    func test_percentage_aboveTen() {
        XCTAssertEqual(Formatters.percentage(12.8), "12.8%")
    }

    func test_percentage_exactTen() {
        XCTAssertEqual(Formatters.percentage(10.0), "10.0%")
    }

    func test_percentage_large() {
        XCTAssertEqual(Formatters.percentage(99.99), "100.0%")
    }

    // MARK: - Relative date

    func test_relative_now() {
        let now = Date()
        let result = Formatters.relative(now)
        XCTAssertTrue(result == "now" || result.contains("sec.") || result.contains("min."))
    }

    func test_relative_oneHourAgo() {
        let past = Date().addingTimeInterval(-3600)
        let result = Formatters.relative(past)
        XCTAssertTrue(result.contains("hr.") || result.contains("hour") || result.contains("min."))
    }

    func test_relative_yesterday() {
        let past = Date().addingTimeInterval(-86400)
        let result = Formatters.relative(past)
        XCTAssertTrue(result.lowercased().contains("day") || result.contains("hr."))
    }
}
