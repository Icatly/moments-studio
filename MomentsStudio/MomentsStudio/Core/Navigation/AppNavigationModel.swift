import Foundation
import Observation

/// Owns navigation state for the whole app.
///
/// `RootView` is the only place that binds this model to `NavigationStack` and
/// `.sheet`; individual screens ask for a destination instead of owning
/// presentation flags. That keeps Home → Project/Editor → Settings behaviour
/// testable without instantiating any view.
///
/// Main actor: navigation state is UI state, so this type is `@MainActor`-
/// isolated. Views bind it from `RootView`; tests isolate themselves with
/// `@MainActor` on the test method.
@MainActor
@Observable
final class AppNavigationModel {
    /// Pushed screens, outermost first.
    var path: [AppRoute] = []

    /// Currently presented modal, if any.
    var sheet: SheetRoute?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    /// Pops one screen. No-op at the root so callers do not need to guard.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Returns to Home. Kept for programmatic navigation (for example after a
    /// project is deleted); the system back button drives the common case.
    func popToRoot() {
        path.removeAll()
    }

    func present(_ route: SheetRoute) {
        sheet = route
    }

    func dismissSheet() {
        sheet = nil
    }
}
