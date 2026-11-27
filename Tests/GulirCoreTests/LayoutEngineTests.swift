import CoreGraphics
import XCTest
@testable import GulirCore

final class LayoutEngineTests: XCTestCase {
    private let area = CGRect(x: 0, y: 33, width: 1000, height: 800)
    private let gap: CGFloat = 10
    private let half: CGFloat = 0.5

    private func run(_ fractions: [CGFloat], focus: Int, scroll: CGFloat = 0,
                     center: Bool = false) -> LayoutEngine.Result {
        LayoutEngine.layout(fractions: fractions, focus: focus, scroll: scroll,
                            area: area, gap: gap, center: center)
    }

    private func isFullyVisible(_ r: CGRect) -> Bool {
        r.minX >= area.minX + gap - 0.5 && r.maxX <= area.maxX - gap + 0.5
    }

    func testColumnWidthDoesNotDependOnColumnCount() {
        let two = run([half, half], focus: 0)
        let five = run(Array(repeating: half, count: 5), focus: 0)
        XCTAssertEqual(two.placements[0].frame.width, five.placements[0].frame.width)
        XCTAssertEqual(two.placements[1].frame.width, five.placements[1].frame.width)
    }

    func testTwoHalvesFillScreenWithEqualGaps() {
        let r = run([half, half], focus: 0)
        let a = r.placements[0].frame, b = r.placements[1].frame
        XCTAssertEqual(a.minX - area.minX, gap, accuracy: 0.001)
        XCTAssertEqual(b.minX - a.maxX, gap, accuracy: 0.001)
        XCTAssertEqual(area.maxX - b.maxX, gap, accuracy: 0.001)
        XCTAssertEqual(a.minY, area.minY + gap)
        XCTAssertEqual(a.height, area.height - 2 * gap)
    }

    func testFocusedColumnIsAlwaysFullyVisible() {
        let fractions: [CGFloat] = [1.0 / 3.0, half, 2.0 / 3.0, 1.0, half, half]
        var scroll: CGFloat = 0
        for focus in [0, 5, 2, 3, 1, 4, 0] {
            let r = run(fractions, focus: focus, scroll: scroll)
            XCTAssertTrue(isFullyVisible(r.placements[focus].frame), "focus \(focus)")
            scroll = r.scroll
        }
    }

    func testFocusingAlreadyVisibleColumnDoesNotScroll() {
        let fractions = Array(repeating: half, count: 4)
        let first = run(fractions, focus: 2)
        // Kolom 1 dan 2 terlihat penuh; pindah fokus ke kolom 1 tidak boleh menggeser strip
        XCTAssertTrue(isFullyVisible(first.placements[1].frame))
        let second = run(fractions, focus: 1, scroll: first.scroll)
        XCTAssertEqual(second.scroll, first.scroll)
    }

    // Bug A: setelah kolom paling kanan hilang, separuh layar kanan kosong.
    func testRemovingLastColumnLeavesNoEmptySpaceOnTheRight() {
        let before = run([half, half, half], focus: 2)
        let after = run([half, half], focus: 1, scroll: before.scroll)
        XCTAssertEqual(area.maxX - after.placements[1].frame.maxX, gap, accuracy: 0.001)
        XCTAssertTrue(isFullyVisible(after.placements[0].frame))
    }

    func testStripNarrowerThanScreenIsLeftAligned() {
        let r = run([half], focus: 0, scroll: 300)
        XCTAssertEqual(r.placements[0].frame.minX, area.minX + gap, accuracy: 0.001)
    }

    func testCenterIsClampedAtStripEdges() {
        let fractions = [CGFloat](repeating: 1.0 / 3.0, count: 5)
        let middle = run(fractions, focus: 2, center: true)
        XCTAssertEqual(middle.placements[2].frame.midX, area.midX, accuracy: 0.001)
        let edge = run(fractions, focus: 0, center: true)
        XCTAssertEqual(edge.placements[0].frame.minX, area.minX + gap, accuracy: 0.001)
    }

    func testOffscreenColumnsAreParkedWithOnePixelLeft() {
        let r = run(Array(repeating: half, count: 5), focus: 4)
        guard case .parked(.left, let left) = r.placements[0] else { return XCTFail("kolom 0 harus diparkir kiri") }
        XCTAssertEqual(left.maxX, area.minX + 1, accuracy: 0.001)

        let r2 = run(Array(repeating: half, count: 5), focus: 0)
        guard case .parked(.right, let right) = r2.placements[4] else { return XCTFail("kolom 4 harus diparkir kanan") }
        XCTAssertEqual(right.minX, area.maxX - 1, accuracy: 0.001)
    }

    // Bug B: jendela yang lebih lebar dari kolomnya (lebar minimum app) harus tetap tersembunyi.
    func testParkedXUsesActualWindowWidth() {
        let x = LayoutEngine.parkedX(.left, width: 800, area: area)
        XCTAssertEqual(x + 800, area.minX + 1, accuracy: 0.001)
    }

    func testEmptyInput() {
        XCTAssertEqual(run([], focus: 0, scroll: 42), LayoutEngine.Result(placements: [], scroll: 42))
    }
}
