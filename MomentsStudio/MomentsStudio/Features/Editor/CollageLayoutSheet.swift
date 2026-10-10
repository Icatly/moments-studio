import SwiftUI

/// Read-only previews until Apply commits through the existing edit coordinator.
@MainActor
struct CollageLayoutSheet: View {
    let projectID: UUID

    @Environment(ProjectStore.self) private var store
    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(AppNavigationModel.self) private var navigation
    /// Search activation state.
    ///
    /// Real evidence (run 37957684567): after typing `OFFSET` the keyboard stayed up
    /// and covered the filtered choice (`layout.choose.offset` at y=541.3 inside a
    /// 0...874 window sat inside `layout.scroll` but was not usable). The search
    /// interface is ended by setting this binding to `false` on submit — a plain
    /// state write in the same view that owns `.searchable`, which is exactly the
    /// documented iOS 17 activation control. Unlike `dismissSearch`, it neither
    /// depends on an environment value that does not travel up to the outer view
    /// nor clears `query`, so the `OFFSET` filter and the no-results state survive.
    @State private var searchIsPresented = false

    @State private var selected: CollagePreset?
    @State private var query = ""
    @State private var reloadID = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    if let project = store.openProject(id: projectID) {
                        Text("Three layouts with your photos")
                            .font(Typography.sectionTitle)
                        Text(project.document.layers.isEmpty
                             ? (PhotoRoleLayoutPlan.hasNoLayoutParticipant(store.photos(for: projectID))
                                ? "Every photo is saved as collage material or not for layout. Change a role in Photo roles to include one."
                                : "Uses your imported photos. Choose a layout, then tap Apply.")
                             : "Arranges visible, unlocked photo layers. Locked and hidden layers stay unchanged.")
                            .font(Typography.body)
                            .foregroundStyle(Color.secondary)

                        if let selected {
                            Text("Selected layout: \(selected.title)")
                                .font(Typography.body)
                                .accessibilityIdentifier("layout.selection")
                        }

                        let presets = CollagePreset.allCases.filter { $0.matches(query) }
                        if presets.isEmpty {
                            Text("No matching layouts.")
                                .accessibilityIdentifier("layout.noResults")
                            Button("Clear search") { query = "" }
                                .frame(minHeight: Layout.minimumTapTarget)
                                .accessibilityIdentifier("layout.clearSearch")
                        } else {
                            ForEach(presets) { preset in
                                choice(preset, project: project)
                                Divider()
                            }
                        }

                        Button("Reload previews") { reloadID += 1 }
                            .frame(minHeight: Layout.minimumTapTarget)
                            .disabled(photoImport.isBusy)
                            .accessibilityIdentifier("layout.reload")

                        if photoImport.isSavingEdits {
                            ProgressView("Saving…")
                                .accessibilityIdentifier("layout.saving")
                        }
                        if let message = photoImport.editMessage(for: projectID) {
                            Text(message)
                                .foregroundStyle(Color.secondary)
                                .accessibilityIdentifier("layout.message")
                        }
                        if photoImport.failedDraft(for: projectID) != nil {
                            Button("Retry save") {
                                Task { finish(await photoImport.retryFailedDraft(projectID: projectID)) }
                            }
                            .frame(minHeight: Layout.minimumTapTarget)
                            .disabled(photoImport.isBusy)
                            .accessibilityIdentifier("layout.retry")
                            Button("Discard unsaved change") {
                                photoImport.discardFailedDraft(projectID: projectID)
                            }
                            .frame(minHeight: Layout.minimumTapTarget)
                            .disabled(photoImport.isBusy)
                            .accessibilityIdentifier("layout.discard")
                        }
                    } else {
                        Text("This project is no longer available.")
                            .accessibilityIdentifier("layout.missingProject")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.medium)
            }
            .accessibilityIdentifier("layout.scroll")
            .navigationTitle("Layouts")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, isPresented: $searchIsPresented,
                        placement: .navigationBarDrawer(displayMode: .always), prompt: "Find a layout")
            .onSubmit(of: .search) { searchIsPresented = false }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissIfCurrent() }
                        .frame(minHeight: Layout.minimumTapTarget)
                        .disabled(photoImport.isBusy)
                        .accessibilityIdentifier("layout.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        guard let selected else { return }
                        Task {
                            finish(await photoImport.applyCanvasIntent(
                                projectID: projectID, layerID: nil, intent: .layout(selected)
                            ))
                        }
                    }
                    .frame(minHeight: Layout.minimumTapTarget)
                    .disabled(!canApply)
                    .accessibilityIdentifier("layout.apply")
                }
            }
        }
        .interactiveDismissDisabled(photoImport.isBusy)
    }

    private var isEditingDisabled: Bool {
        !photoImport.isReady || photoImport.isBusy || photoImport.failedDraft(for: projectID) != nil
    }

    private var canApply: Bool {
        guard !isEditingDisabled, let selected, let project = store.openProject(id: projectID) else { return false }
        return (try? CollageLayout.arrange(selected, document: project.document, photos: store.photos(for: projectID))) != nil
    }

    @ViewBuilder
    private func choice(_ preset: CollagePreset, project: Project) -> some View {
        let photos = store.photos(for: projectID)
        let preview = Result { try CollageLayout.arrange(preset, document: project.document, photos: photos) }
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(preset.title)
                .font(Typography.sectionTitle)
            Text(preset.summary)
                .font(Typography.body)
                .foregroundStyle(Color.secondary)
            switch preview {
            case .success(let document):
                EditorCanvasView(
                    projectID: projectID, document: document, photos: photos,
                    selectedLayerID: .constant(nil), isEditingDisabled: true
                )
                .id(reloadID)
                .frame(height: 200)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(preset.title) preview using your photos")
                .accessibilityIdentifier("layout.preview.\(preset.rawValue)")
                Button(selected == preset ? "Selected: \(preset.title)" : "Choose \(preset.title)") {
                    selected = preset
                }
                .frame(minHeight: Layout.minimumTapTarget)
                .disabled(isEditingDisabled)
                .accessibilityIdentifier("layout.choose.\(preset.rawValue)")
                .accessibilityValue(selected == preset ? "Selected" : "Not selected")
            case .failure(let error):
                Text(error.localizedDescription)
                    .font(Typography.body)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("layout.error.\(preset.rawValue)")
            }
        }
    }

    private func finish(_ outcome: PhotoImportModel.CanvasEditOutcome) {
        if case .saved = outcome { dismissIfCurrent() }
    }

    private func dismissIfCurrent() {
        if navigation.sheet == .collageLayout(projectID: projectID) {
            navigation.dismissSheet()
        }
    }
}
