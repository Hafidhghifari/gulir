import CoreGraphics
import XCTest
@testable import GulirCore

final class SwipeTrackerTests: XCTestCase {
    private func feed(_ tracker: inout SwipeTracker, _ deltas: [CGFloat], dy: CGFloat = 0) -> [SwipeTracker.Step] {
        var steps = tracker.feed(deltaX: 0, deltaY: 0, phase: .began)
        for d in deltas { steps += tracker.feed(deltaX: d, deltaY: dy, phase: .changed) }
        steps += tracker.feed(deltaX: 0, deltaY: 0, phase: .ended)
        return steps
    }

    func testSmallSwipeDoesNothing() {
        var t = SwipeTracker(threshold: 80)
        XCTAssertEqual(feed(&t, [-20, -30, -20]), [])
    }

    func testNegativeDeltaFocusesRight() {
        var t = SwipeTracker(threshold: 80)
        XCTAssertEqual(feed(&t, [-30, -30, -30]), [.right])
    }

    func testPositiveDeltaFocusesLeft() {
        var t = SwipeTracker(threshold: 80)
        XCTAssertEqual(feed(&t, [50, 50]), [.left])
    }

    func testLongSwipeGivesSeveralSteps() {
        var t = SwipeTracker(threshold: 80)
        XCTAssertEqual(feed(&t, [-100, -100, -50]), [.right, .right, .right])
    }

    func testVerticalScrollIsIgnored() {
        var t = SwipeTracker(threshold: 80)
        XCTAssertEqual(feed(&t, [-40, -40, -40], dy: 100), [])
    }

    func testLeftoverDoesNotCarryIntoNextGesture() {
        var t = SwipeTracker(threshold: 80)
        XCTAssertEqual(feed(&t, [-70]), [])
        XCTAssertEqual(feed(&t, [-70]), [])
    }

    func testChangingDirectionMidSwipe() {
        var t = SwipeTracker(threshold: 80)
        XCTAssertEqual(feed(&t, [-90, 100, 60]), [.right, .left])
    }
}
