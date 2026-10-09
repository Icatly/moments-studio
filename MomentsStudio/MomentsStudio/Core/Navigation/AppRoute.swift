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
/// Stage 01 presented one sheet to prove the seam works; Stage 02 adds the
/// read-only photo preview. `RootView` handles every case, so modal state stays
/// inspectable in one place and no screen invents presentation flags. The one
/// deliberate exception is the system photo picker's own selection binding,
/// which is import UI state rather than app navigation.
enum SheetRoute: Identifiable, Hashable {
    case about
    case photoPreview(projectID: UUID, assetID: UUID)
    case collageLayout(projectID: UUID)

    var id: Self { self }
}
