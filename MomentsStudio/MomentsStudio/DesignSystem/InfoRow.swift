import SwiftUI

/// Minimal label/value row used by the Stage 01 placeholder screens.
///
/// Deliberately plain and unthemed: the approved information-row design does
/// not exist yet, so this only uses system fonts and semantic colors.
struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
            Text(title)
                .font(Typography.body)
            Spacer(minLength: Spacing.small)
            Text(value)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
