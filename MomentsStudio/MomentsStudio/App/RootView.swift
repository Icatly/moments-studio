import SwiftUI

/// The only place where app state meets the navigation container.
///
/// Screens receive `ProjectStore`, `AppNavigationModel` and `PhotoImportModel`
/// through the environment and never own navigation flags themselves, so the
/// shell stays testable and later stages can add screens without touching this
/// file beyond one switch case.
///
/// `@MainActor` is stated explicitly and deliberately **not** left to SwiftUI
/// inference: this type initializes the main-actor-isolated state objects, and
/// whether a whole `View` type inherits the main actor from its protocol is an
/// SDK-level detail that this project does not want to depend on. Every screen
/// in this target that touches main-actor state carries the same explicit
/// annotation (`HomeView`, `EditorPlaceholderView`, `SettingsPlaceholderView`),
/// as does the `App` entry point that constructs this view.
@MainActor
struct RootView: View {
    @State private var navigation = AppNavigationModel()
    @State private var projectStore: ProjectStore
    @State private var photoImport: PhotoImportModel

    init() {
        let store = ProjectStore()
        _projectStore = State(initialValue: store)
        _photoImport = State(initialValue: PhotoImportModel.makeDefault(store: store))
    }

    var body: some View {
        @Bindable var navigation = navigation

        NavigationStack(path: $navigation.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .environment(navigation)
        .environment(projectStore)
        .environment(photoImport)
        .sheet(item: $navigation.sheet) { route in
            // Attach the same root-owned instances to the presented content.
            //
            // The observed runtime failure (run 37138644682, Appetize
            // iPhone 14 Pro / iOS 17.2) was: opening an imported photo's preview
            // exited the app with
            // "SwiftUI/Environment+Objects.swift:32: Fatal error: No Observable
            // object of type PhotoImportModel found". The three environments were
            // attached before this `.sheet`, and the presented content did not
            // receive them on that path, so the preview's required
            // `PhotoImportModel`/`ProjectStore` were missing. This is a modal
            // dependency wiring defect — not an image-decoding or storage defect —
            // and the repair is to hand the modal the *same* instances explicitly.
            // No new state, store or coordinator is introduced.
            sheet(for: route)
                .environment(navigation)
                .environment(projectStore)
                .environment(photoImport)
        }
        .task {
            // Startup restoration is asynchronous: Home shows loading until the
            // saved packages are merged, and disables creation meanwhile.
            await photoImport.restoreProjects()
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .editor(let projectID):
            EditorPlaceholderView(projectID: projectID)
        case .settings:
            SettingsPlaceholderView()
        }
    }

    @ViewBuilder
    private func sheet(for route: SheetRoute) -> some View {
        switch route {
        case .about:
            AboutSheet()
        case .photoPreview(let projectID, let assetID):
            PhotoPreviewSheet(projectID: projectID, assetID: assetID)
        }
    }
}
