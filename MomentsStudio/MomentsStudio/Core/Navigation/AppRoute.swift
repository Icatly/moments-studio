import Foundation

/// Push-navigation destinations.
///
/// Routes carry identifiers, never model values: the destination reads current
/// state from `ProjectStore`, so a renamed or deleted project can never be
/// shown through a stale copy.
enum AppRoute: Hashable {
    case editor(projectID: UUID)
    case settings
}

/// Modal destinations.
///
/// Stage 01 presents one sheet to prove the seam works before later stages add
/// real sheets (photo import, templates, export). Screen-local presentation
/// flags are deliberately avoided so modal state stays inspectable in one place.
enum SheetRoute: Identifiable, Hashable {
    case about

    var id: Self { self }
}
