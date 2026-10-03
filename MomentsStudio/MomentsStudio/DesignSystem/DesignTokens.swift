import SwiftUI

// Neutral placeholder tokens for the Stage 01 shell.
//
// These values are temporary scaffolding, not a brand. The approved visual
// system will be defined by the project owner in `docs/design/UI_DESIGN_SYSTEM.md`
// and can replace this file wholesale.
//
// Only tokens that Stage 01 actually uses are declared here, so no part of an
// unapproved design is locked in early.

/// Layout rhythm.
enum Spacing {
    static let extraSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

/// Corner radii.
enum Radius {
    static let thumbnail: CGFloat = 8
}

/// Semantic colors. `accent` resolves to `AccentColor` in the asset catalog.
enum Palette {
    static let accent = Color.accentColor
    static let thumbnailFill = Color.secondary.opacity(0.15)
}

/// Text styles. All entries are system text styles, so Dynamic Type works
/// without extra code.
enum Typography {
    static let sectionTitle = Font.headline
    static let body = Font.body
    static let caption = Font.footnote
}

/// Timing for the small state-change animations the shell uses.
enum Motion {
    static let listUpdate = Animation.easeOut(duration: 0.2)
}

/// Shared layout metrics.
enum Layout {
    /// Minimum tappable height (Apple HIG: 44 pt).
    static let minimumTapTarget: CGFloat = 44
}
