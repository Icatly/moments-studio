import SwiftUI

/// Settings placeholder.
///
/// Every row states current, factual status; nothing here pretends a feature
/// exists. The About row presents a sheet so the modal navigation seam is
/// exercised before later stages add real sheets.
///
/// `@MainActor` is stated explicitly rather than left to SwiftUI inference: the
/// view starts a navigation action on the main-actor-isolated model.
@MainActor
struct SettingsPlaceholderView: View {
    @Environment(AppNavigationModel.self) private var navigation

    var body: some View {
        List {
            Section {
                Button {
                    navigation.present(.about)
                } label: {
                    Label("About \(AppInfo.displayName)", systemImage: "info.circle")
                }
                .accessibilityIdentifier("settings.about")
            }

            Section {
                InfoRow(title: "Photo access", value: "Not requested yet")
                InfoRow(title: "Processing", value: "Not implemented")
                InfoRow(title: "Cloud services", value: "None")
                InfoRow(title: "Editing", value: "Not implemented")
                InfoRow(title: "Export", value: "Not implemented")
            } header: {
                Text("Status")
                    .font(Typography.sectionTitle)
            } footer: {
                // Explicit `Color.secondary` rather than the hierarchical
                // `.secondary` style, which renders too faint inside a list
                // footer in both colour schemes.
                Text("Settings has no user-adjustable options in Stage 01.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
            }

            Section {
                InfoRow(title: "Version", value: "\(AppInfo.version) (\(AppInfo.build))")
                InfoRow(title: "Stage", value: AppInfo.stageLabel)
            } header: {
                Text("Build")
                    .font(Typography.sectionTitle)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}
