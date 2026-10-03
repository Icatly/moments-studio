import SwiftUI

/// Home: entry point with the Create Project action and the session-only
/// recent projects list.
///
/// `@MainActor` is stated explicitly rather than left to SwiftUI inference: this
/// view reaches main-actor-isolated project state from its private computed
/// properties and from the `open` helper, not only from `body`.
@MainActor
struct HomeView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(AppNavigationModel.self) private var navigation
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Section {
                createProjectButton
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
                Text("Stage 01 keeps this list in memory for the current session only. Projects are not saved to the device yet.")
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

    private var createProjectButton: some View {
        Button {
            let project = projectStore.createProject()
            navigation.push(.editor(projectID: project.id))
        } label: {
            Label("Create Project", systemImage: "plus")
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(createProjectLabelColor)
                .frame(maxWidth: .infinity, minHeight: Layout.minimumTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.accent)
        .accessibilityIdentifier("home.createProject")
        .accessibilityHint("Creates an empty project and opens the editor placeholder")
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
                    RecentProjectRow(project: project)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.project.\(project.id.uuidString)")
                .accessibilityHint("Opens the editor placeholder for this project")
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
                Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: Layout.minimumTapTarget)
        .contentShape(Rectangle())
    }
}
