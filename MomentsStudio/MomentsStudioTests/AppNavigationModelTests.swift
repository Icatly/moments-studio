import XCTest
@testable import MomentsStudio

/// `AppNavigationModel` is `@MainActor`-isolated; see `ProjectStoreTests` for why
/// the annotation sits on each test method rather than on the subclass.
final class AppNavigationModelTests: XCTestCase {
    @MainActor
    func testStartsAtRootWithNoSheet() async {
        let navigation = AppNavigationModel()

        XCTAssertTrue(navigation.path.isEmpty)
        XCTAssertNil(navigation.sheet)
    }

    @MainActor
    func testPushAndPopMoveThroughTheStack() async {
        let navigation = AppNavigationModel()
        let projectID = UUID()

        navigation.push(.editor(projectID: projectID))
        navigation.push(.settings)

        XCTAssertEqual(navigation.path, [.editor(projectID: projectID), .settings])

        navigation.pop()
        XCTAssertEqual(navigation.path, [.editor(projectID: projectID)])

        navigation.pop()
        XCTAssertTrue(navigation.path.isEmpty)
    }

    @MainActor
    func testPopAtRootDoesNothing() async {
        let navigation = AppNavigationModel()

        navigation.pop()

        XCTAssertTrue(navigation.path.isEmpty)
    }

    @MainActor
    func testPopToRootClearsTheStack() async {
        let navigation = AppNavigationModel()
        navigation.push(.editor(projectID: UUID()))
        navigation.push(.settings)

        navigation.popToRoot()

        XCTAssertTrue(navigation.path.isEmpty)
    }

    @MainActor
    func testSheetPresentAndDismiss() async {
        let navigation = AppNavigationModel()

        navigation.present(.about)
        XCTAssertEqual(navigation.sheet, .about)

        navigation.dismissSheet()
        XCTAssertNil(navigation.sheet)
    }
}
