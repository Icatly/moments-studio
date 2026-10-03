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
}
