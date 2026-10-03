import SwiftUI

/// The Stage 02 editor screen.
///
/// There is still no canvas: this stage adds photo import, a thumbnail gallery,
/// a read-only preview and removal. The copy says that plainly instead of
/// implying that editing exists.
///
/// `@MainActor` is stated explicitly rather than left to SwiftUI inference: the
/// view reads the main-actor-isolated store from `navigationTitle` and from
/// `content(for:)`, not only from `body`.
@MainActor
struct EditorPlaceholderView: View {
    let projectID: UUID

    @Environment(ProjectStore.self) private var projectStore
    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(AppNavigationModel.self) private var navigation

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
        .onDisappear {
            // Leaving the editor stops the remaining work of a running batch;
            // committed photos stay. Presenting the preview sheet keeps
            // `.editor` on the navigation path, so only a real navigation
            // change (Back) cancels.
            if !navigation.path.contains(.editor(projectID: projectID)) {
                photoImport.cancelImport(projectID: projectID)
            }
        }
    }

    private var navigationTitle: String {
        projectStore.openProject(id: projectID)?.name ?? "Project"
    }

    private var missingProjectState: some View {
        Text("This project is not available in the current session.")
            .font(Typography.body)
            .foregroundStyle(Color.secondary)
            .multilineTextAlignment(.center)
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("editor.missingProject")
    }

    private func content(for project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Editor")
                        .font(Typography.sectionTitle)
                        .accessibilityIdentifier("editor.placeholder")
                    Text("Photo import is available. The canvas, layers, layouts, cutouts, styling, manual editing and export are not implemented yet.")
                        .font(Typography.body)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("editor.status")
                }

                PhotoImportSection(projectID: projectID)

                projectState(for: project)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.medium)
        }
    }

    private func projectState(for project: Project) -> some View {
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
            InfoRow(title: "Photos", value: "\(projectStore.photos(for: projectID).count)")
            Divider()
            InfoRow(
                title: "Saved on device",
                value: projectStore.savedProjectIDs.contains(projectID)
                    ? "Yes"
                    : "Not yet — import a photo to save this project"
            )
        }
    }
}
