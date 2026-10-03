import XCTest

extension XCUIElement {
    /// Waits until the element exists **and** is enabled.
    ///
    /// Since Stage 02, Home keeps Create and Import disabled until the photo
    /// library has finished loading, so `waitForExistence` alone can hand back a
    /// control that is not tappable yet. Used by every smoke test that taps.
    func waitUntilEnabled(timeout: TimeInterval = 20) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the element no longer exists, within a bounded timeout.
    ///
    /// `waitForExistence(timeout:)` returns *immediately* when the element still
    /// exists, so it cannot assert that something disappeared while a dismissal
    /// is still underway. This waits for `exists == false` and only reports
    /// success once the element is really gone.
    func waitForDisappearance(timeout: TimeInterval = 20) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
