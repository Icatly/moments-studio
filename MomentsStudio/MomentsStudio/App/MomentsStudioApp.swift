import SwiftUI

/// `@MainActor` is stated explicitly rather than left to inference: the scene
/// closure constructs `RootView`, whose initializer creates the two
/// main-actor-isolated state objects.
@main
@MainActor
struct MomentsStudioApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
