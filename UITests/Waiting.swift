import XCTest

/// XCTest's own waits (`waitForExistence`, predicate expectations) look again only once a second, so each one
/// cost a whole second even when the screen was ready a moment later: a third of the suite. These look every 50 ms.
func eventually(within timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
    let deadline = Date.now + timeout
    while !condition() {
        guard Date.now < deadline else { return false }
        RunLoop.current.run(until: .now + 0.05)
    }
    return true
}

extension XCUIElement {
    func appears(within timeout: TimeInterval) -> Bool {
        eventually(within: timeout) { exists }
    }
}

extension XCUIElement {
    /// True once the element has stood still for 5 looks (250 ms): a sheet still sliding in shows its buttons
    /// half drawn, and one unchanged look can fall between two animation frames.
    func settles(within timeout: TimeInterval) -> Bool {
        var last = CGRect.null
        var stillLooks = 0
        return eventually(within: timeout) {
            let now = frame
            stillLooks = now == last ? stillLooks + 1 : 0
            last = now
            return stillLooks >= 5
        }
    }
}
