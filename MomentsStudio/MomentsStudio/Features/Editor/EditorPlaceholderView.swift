import SwiftUI

/// The manual canvas editor, with photo tools in a separate scroll area.
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

    /// Selection is view state only: it is never serialized with the document.
    @State private var selectedLayerID: UUID?
    @State private var reloadID = 0

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    Task {
                        let outcome = await photoImport.applyCanvasIntent(projectID: projectID, layerID: nil, intent: .save)
                        if case .saved = outcome, navigation.path.last == .editor(projectID: projectID) {
                            navigation.popToRoot()
                        }
                    }
                }
                .frame(minHeight: Layout.minimumTapTarget)
                .disabled(isEditingDisabled || !photoImport.isReady || projectStore.openProject(id: projectID) == nil)
                .accessibilityIdentifier("editor.done")
                .accessibilityHint("Saves this project and returns to Home")
            }
        }
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
        GeometryReader { geometry in
          VStack(spacing: 0) {
            // The canvas is its own gesture area on purpose: it must not sit inside
            // the vertical scroll view below, or a single-finger drag would scroll
            // the page instead of moving the photo.
            EditorCanvasView(
                projectID: projectID,
                document: project.document,
                photos: projectStore.photos(for: projectID),
                selectedLayerID: $selectedLayerID,
                isEditingDisabled: isEditingDisabled,
                reloadID: reloadID
            )
            .frame(height: min(360, max(100, geometry.size.height * 0.42)))
            .padding(.horizontal, Spacing.medium)
            .padding(.top, Spacing.medium)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Editor")
                            .font(Typography.sectionTitle)
                            .accessibilityIdentifier("editor.placeholder")
                        Text("Add photos from your library to the canvas, then move, scale, rotate, reorder, hide, lock, reset or remove layers.")
                            .font(Typography.body)
                            .foregroundStyle(Color.secondary)
                            .accessibilityIdentifier("editor.status")
                    }

                    // The two optional photo tools share one row: a separate
                    // "Photo summary" row pushed the primary "Import Photos" entry
                    // to y=872.3...916.3 in the 0...874 window (run 37966461191), so
                    // the import entry could not be tapped at all. Same buttons, same
                    // targets, identifiers, disabled rules and routes, one row.
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        Button("Layouts") {
                            navigation.present(.collageLayout(projectID: projectID))
                        }
                        .frame(minHeight: Layout.minimumTapTarget)
                        .disabled(isEditingDisabled || !photoImport.isReady || projectStore.photos(for: projectID).isEmpty)
                        .accessibilityIdentifier("editor.layouts")
                        .accessibilityHint("Preview three layouts before applying one")

                        Button("Photo summary") {
                            navigation.present(.photoAnalysis(projectID: projectID))
                        }
                        .frame(minHeight: Layout.minimumTapTarget)
                        .disabled(isEditingDisabled || !photoImport.isReady || projectStore.photos(for: projectID).isEmpty)
                        .accessibilityIdentifier("editor.photoSummary")
                        .accessibilityHint("Estimates light and colour for each imported photo")
                    }

                    EditorLayerListView(
                        projectID: projectID,
                        document: project.document,
                        photos: projectStore.photos(for: projectID),
                        selectedLayerID: $selectedLayerID,
                        isEditingDisabled: isEditingDisabled,
                        reloadSelectedPhoto: { reloadID += 1 }
                    )

                    PhotoImportSection(projectID: projectID)

                    projectState(for: project)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.medium)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.interaction, Rectangle())
            .clipped()
          }
        }
        .onChange(of: project.document.layers.map(\.id)) { _, ids in
            if let selectedLayerID, !ids.contains(selectedLayerID) { self.selectedLayerID = nil }
        }
    }

    /// Conflicting edits are disabled while a mutation is in flight, and the UI can
    /// therefore show a real saving state instead of a fake "saved".
    private var isEditingDisabled: Bool {
        photoImport.isBusy || photoImport.failedDraft(for: projectID) != nil
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
                value: String(format: "%.0f × %.0f", project.document.canvasSize.width, project.document.canvasSize.height)
            )
            Divider()
            InfoRow(title: "Layers", value: "\(project.document.layers.count)")
            Divider()
            InfoRow(title: "Photos", value: "\(projectStore.photos(for: projectID).count)")
            Divider()
            InfoRow(
                title: "Saved on device",
                value: photoImport.failedDraft(for: projectID) != nil
                    ? "Changes not saved"
                    : photoImport.isSavingEdits ? "Saving…"
                    : projectStore.savedProjectIDs.contains(projectID)
                    ? "Yes"
                    : "Not yet — tap Done or import a photo to save this project"
            )
        }
    }
}
