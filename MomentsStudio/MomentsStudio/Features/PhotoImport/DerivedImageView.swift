import CoreGraphics
import SwiftUI

/// Loads one photo-library derivative on demand and draws it.
///
/// The grid asks only for the thumbnails it is showing, and the preview sheet
/// asks only for the current photo's 2048px derivative, so nothing is preloaded
/// in bulk and no original file is ever decoded for display.
///
/// A failed load shows an explicit unavailable placeholder with a retry instead
/// of spinning forever, and a result that arrives after the reference changed is
/// discarded.
///
/// `@MainActor` is stated explicitly rather than left to SwiftUI inference,
/// consistent with the rest of this target: the view calls the main-actor
/// loader closure from a helper.
@MainActor
struct DerivedImageView<Placeholder: View>: View {
    let reference: String
    let contentMode: ContentMode
    let load: @MainActor (String) async -> CGImage?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var phase: Phase = .loading
    @State private var attempt = 0

    private enum Phase {
        case loading
        case loaded(CGImage)
        case failed
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                placeholder()

            case .loaded(let image):
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)

            case .failed:
                unavailable
            }
        }
        .task(id: "\(reference)#\(attempt)") {
            phase = .loading
            let loaded = await load(reference)
            // `.task(id:)` cancels the previous task when the id changes, so a
            // late result for an older reference cannot overwrite a newer one.
            guard !Task.isCancelled else { return }
            phase = loaded.map { Phase.loaded($0) } ?? .failed
        }
    }

    /// Shown when the derivative exists in the record but cannot be read.
    private var unavailable: some View {
        VStack(spacing: Spacing.extraSmall) {
            Image(systemName: "photo.badge.exclamationmark")
                .foregroundStyle(Color.secondary)

            Button("Retry") {
                attempt += 1
            }
            .font(Typography.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("photo.unavailable")
    }
}
