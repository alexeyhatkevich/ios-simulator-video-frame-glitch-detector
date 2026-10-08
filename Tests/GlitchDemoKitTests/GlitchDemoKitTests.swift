import XCTest
@testable import GlitchDemoKit

@MainActor
final class GlitchDemoKitTests: XCTestCase {

    // MARK: title flash

    func test_naive_title_is_blank_right_after_entry() {
        // Proves: the band is empty on the first frame after entry (the flash).
        let header = TitleHeaderView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        header.mode = .naive
        header.show(title: "Settings")
        XCTAssertNil(header.label.text)
    }

    func test_naive_title_appears_only_after_the_binding_delay() {
        // Proves: the text does arrive, late - that is the "blank for N ms" window.
        let header = TitleHeaderView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        header.mode = .naive
        header.bindingDelay = 0.05
        header.show(title: "Settings")
        let done = expectation(description: "bound")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 1)
        XCTAssertEqual(header.label.text, "Settings")
    }

    func test_fixed_title_is_present_immediately() {
        // Proves: no blank window at all.
        let header = TitleHeaderView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        header.mode = .fixed
        header.show(title: "Settings")
        XCTAssertEqual(header.label.text, "Settings")
    }

    // MARK: dot shape

    func test_naive_selected_dot_is_built_with_the_animation_duration_inherited() {
        // Proves: the dot was created inside the animate block (0.4 s inherited).
        let dots = PageDotsView()
        dots.mode = .naive
        dots.select(2)
        XCTAssertEqual(DotView.lastBuildInheritedDuration, 0.4, accuracy: 0.001)
    }

    func test_fixed_selected_dot_is_built_outside_any_animation() {
        // Proves: the dot is created with no inherited duration.
        let dots = PageDotsView()
        dots.mode = .fixed
        dots.select(2)
        XCTAssertEqual(DotView.lastBuildInheritedDuration, 0, accuracy: 0.001)
    }

    func test_fixed_selected_dot_lands_on_the_requested_index() {
        // Proves: the fix still selects correctly.
        let dots = PageDotsView()
        dots.mode = .fixed
        dots.select(3)
        XCTAssertEqual(dots.selectedIndex, 3)
        XCTAssertEqual(dots.selectedDot?.frame.minX, 3 * (DotView.diameter + 16))
    }
}
