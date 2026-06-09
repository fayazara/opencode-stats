import XCTest
@testable import OpenCode_Stats

final class SessionActivityStateTests: XCTestCase {

    private let now = Date()

    func test_updatedWithin2Minutes_isLive() {
        let state = SessionActivityState(lastUpdated: now.addingTimeInterval(-60), now: now)
        XCTAssertEqual(state, .live)
        XCTAssertEqual(state.label, "Live")
    }

    func test_updatedExactly2MinutesAgo_isLive_until120() {
        let state = SessionActivityState(lastUpdated: now.addingTimeInterval(-119), now: now)
        XCTAssertEqual(state, .live)
    }

    func test_updatedBetween2And30Minutes_isRecent() {
        let state = SessionActivityState(lastUpdated: now.addingTimeInterval(-300), now: now)
        XCTAssertEqual(state, .recent)
        XCTAssertEqual(state.label, "Recent")
    }

    func test_updatedAtExactly30Minutes_isRecent() {
        let state = SessionActivityState(lastUpdated: now.addingTimeInterval(-1799), now: now)
        XCTAssertEqual(state, .recent)
    }

    func test_updatedOver30MinutesAgo_isIdle() {
        let state = SessionActivityState(lastUpdated: now.addingTimeInterval(-3600), now: now)
        XCTAssertEqual(state, .idle)
        XCTAssertEqual(state.label, "Idle")
    }

    func test_updatedExactly30MinutesAgo_isIdle() {
        let state = SessionActivityState(lastUpdated: now.addingTimeInterval(-1800), now: now)
        XCTAssertEqual(state, .idle)
    }

    func test_updatedInTheFuture_stillLive() {
        let state = SessionActivityState(lastUpdated: now.addingTimeInterval(60), now: now)
        XCTAssertEqual(state, .live)
    }

    func test_updatedVeryLongAgo_isIdle() {
        let state = SessionActivityState(lastUpdated: now.addingTimeInterval(-86400), now: now)
        XCTAssertEqual(state, .idle)
    }

    func test_usesDefaultNow_whenNowOmitted() {
        let recent = SessionActivityState(lastUpdated: Date().addingTimeInterval(-60))
        XCTAssertEqual(recent, .live)
        let old = SessionActivityState(lastUpdated: Date().addingTimeInterval(-86400))
        XCTAssertEqual(old, .idle)
    }
}
