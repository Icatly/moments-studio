import Foundation

/// Deterministic test gate.
///
/// Lets a test cancel or interleave **while a task is known to be suspended**,
/// using only an actor for shared state — no unsafe `Sendable` escape hatch, no
/// mock repository, no second scheduler.
actor TestGate {
    private var isOpen = false
    private var entries = 0

    /// Suspends until `open()` is called, recording that it was entered.
    func wait() async {
        entries += 1
        while !isOpen {
            await Task.yield()
        }
    }

    /// Blocks the caller's progress cooperatively until at least one waiter has
    /// entered, so a test never guesses at timing.
    func waitUntilEntered() async {
        while entries == 0 {
            await Task.yield()
        }
    }

    func open() {
        isOpen = true
    }
}
