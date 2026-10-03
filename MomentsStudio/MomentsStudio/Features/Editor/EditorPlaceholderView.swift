import SwiftUI

/// Placeholder for the canvas editor (Stage 03+).
///
/// It shows the real in-memory project so navigation and state wiring can be
/// verified, and it states plainly that no editing feature exists yet. Nothing
/// here draws a canvas or fakes a photo.
///
/// `@MainActor` is stated explicitly rather than left to SwiftUI inference: the
/// view reads the main-actor-isolated store from `navigationTitle` and from
/// `content(for:)`, not only from `body`.
@MainActor
struct EditorPlaceholderView: View {
    let projectID: UUID

    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        Group {
            if let project = projectStore.openProject(id: projectID) {
                content(for: project)
            } else {
                missingProjectState
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigationTitle: String {
        projectStore.openProject(id: projectID)?.name ?? "Project"
    }

    private var missingProjectState: some View {
        Text("This project is not available in the current session.")
            .font(Typography.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("editor.missingProject")
    }

    private func content(for project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Editor placeholder")
                        .font(Typography.sectionTitle)
                        .accessibilityIdentifier("editor.placeholder")
                    Text("Photo import, collage layouts, cutouts, styling and export are not implemented in Stage 01. This screen confirms navigation and project state only.")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Project state")
                        .font(Typography.sectionTitle)

                    InfoRow(title: "Name", value: project.name)
                    Divider()
                    InfoRow(title: "Created", value: project.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Divider()
                    InfoRow(
                        title: "Canvas",
                        value: "\(Int(project.document.canvasSize.width)) × \(Int(project.document.canvasSize.height))"
                    )
                    Divider()
                    InfoRow(title: "Layers", value: "\(project.document.layers.count)")
                    Divider()
                    InfoRow(title: "Assets", value: "Not imported yet")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.medium)
        }
    }
}
