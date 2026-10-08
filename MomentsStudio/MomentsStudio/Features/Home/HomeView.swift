import SwiftUI

/// Home: entry point with the Create Project action and the recent projects
/// list.
///
/// Since Stage 02 the list mixes two truthful kinds of project: a project with
/// no photos and no explicit save exists only for this session, while a project
/// saved with Done or by importing photos is restored on the next
/// launch. The copy and the library status section say exactly that.
///
/// `@MainActor` is stated explicitly rather than left to SwiftUI inference: this
/// view reaches main-actor-isolated project state from its private computed
/// properties and from the `open` helper, not only from `body`.
@MainActor
struct HomeView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(AppNavigationModel.self) private var navigation
    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Section {
                createProjectButton
            }

            if showsLibraryStatus {
                Section {
                    libraryStatusContent
                } header: {
                    Text("Saved projects")
                        .font(Typography.sectionTitle)
                }
            }

            Section {
                recentProjectsContent
            } header: {
                Text("Recent Projects")
                    .font(Typography.sectionTitle)
            } footer: {
                // Explicit `Color.secondary` rather than the hierarchical
                // `.secondary` style, which renders too faint inside a list
                // footer in both colour schemes.
                Text("Tap Done in the editor or import a photo to save a project on this device. Projects you leave without saving stay in memory for this session only.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .animation(Motion.listUpdate, value: projectStore.recentProjects)
        .navigationTitle(AppInfo.displayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigation.push(.settings)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityIdentifier("home.settings")
            }
        }
    }

    // MARK: - Create

    private var createProjectButton: some View {
        Button {
            let project = projectStore.createProject()
            navigation.push(.editor(projectID: project.id))
        } label: {
            // The explicit title is intended to let the label wrap at the largest
            // accessibility text size: run 37248700016 still showed
            // "Cre- / ate Proj…" with the outer modifiers alone, so the title is now a
            // real `Text` that may take its full vertical size and any line count,
            // centred. Whether this removes the truncation still awaits verification
            // on a real run. The string, the plus icon, the system body font, the
            // dynamic colour, the 44pt minimum tap target, the create action and the
            // identifier are unchanged.
            Label {
                Text("Create Project")
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "plus")
            }
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(createProjectLabelColor)
            .frame(maxWidth: .infinity, minHeight: Layout.minimumTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.accent)
        // Creating is only safe once the library has finished loading; while it
        // is idle, loading or failed, this stays disabled (Retry is below).
        .disabled(!photoImport.isReady)
        .accessibilityIdentifier("home.createProject")
        .accessibilityHint("Creates an empty project and opens its photo import screen")
    }

    /// Content colour for the prominent Create Project button.
    ///
    /// `AccentColor` is a neutral near-black in light mode and near-white in dark
    /// mode, and this button uses it as its background. A custom tint does not
    /// guarantee that the button style inverts the content for it, so the label
    /// sets its own colour: white on the light-mode dark background, black on the
    /// dark-mode light background.
    private var createProjectLabelColor: Color {
        colorScheme == .dark ? .black : .white
    }

    // MARK: - Library status

    /// Shown only while restoring, after a restore failure, or when the library
    /// reported something the user should know about.
    private var showsLibraryStatus: Bool {
        if photoImport.isRestoring { return true }
        if case .failed = photoImport.restoreState { return true }
        return !photoImport.warnings.isEmpty
    }

    @ViewBuilder
    private var libraryStatusContent: some View {
        switch photoImport.restoreState {
        case .idle, .loading:
            HStack(spacing: Spacing.small) {
                ProgressView()
                Text("Loading saved projects…")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
            }
            .accessibilityIdentifier("home.libraryLoading")

        case .failed(let message):
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(Color.red)
                    .accessibilityIdentifier("home.libraryError")

                Button("Try Again") {
                    Task {
                        await photoImport.restoreProjects()
                    }
                }
                .accessibilityIdentifier("home.libraryRetry")
            }

        case .ready:
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(photoImport.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(Typography.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("home.libraryWarning")
                }

                Button("Dismiss") {
                    photoImport.dismissWarnings()
                }
                .font(Typography.caption)
            }
        }
    }

    // MARK: - Recent projects

    @ViewBuilder
    private var recentProjectsContent: some View {
        if projectStore.recentProjects.isEmpty {
            Text("No projects yet.")
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("home.recentProjects.empty")
        } else {
            ForEach(projectStore.recentProjects) { project in
                Button {
                    open(project)
                } label: {
                    RecentProjectRow(project: project, photoCount: projectStore.photos(for: project.id).count)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.project.\(project.id.uuidString)")
                .accessibilityHint("Opens this project")
            }
        }
    }

    /// Opening only reads state; the project is not modified by navigation.
    private func open(_ project: Project) {
        navigation.push(.editor(projectID: project.id))
    }
}

/// Row for one entry in the recent projects list.
private struct RecentProjectRow: View {
    let project: Project
    let photoCount: Int

    var body: some View {
        HStack(spacing: Spacing.medium) {
            RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous)
                .fill(Palette.thumbnailFill)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                Text(project.name)
                    .font(Typography.body)
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: Layout.minimumTapTarget)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        let created = "Created \(project.createdAt.formatted(date: .abbreviated, time: .shortened))"
        guard photoCount > 0 else { return created }
        return "\(photoCount) photo\(photoCount == 1 ? "" : "s") · \(created)"
    }
}
