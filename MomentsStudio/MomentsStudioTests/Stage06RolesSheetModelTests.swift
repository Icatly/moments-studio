import XCTest
import UniformTypeIdentifiers
@testable import MomentsStudio

/// The value model the Photo roles sheet actually uses: its real draft state
/// (`PhotoRoleDraft`), the shared derivation Save uses, and the change detection that
/// enables the Save button.
///
/// Every case drives the same non-isolated functions the view calls, so a test that
/// passes here is exercising the real interaction model, including role **and**
/// source.
final class Stage06RolesSheetModelTests: XCTestCase {
    private func photo(_ assetID: UUID = UUID(), roleChoice: PhotoRoleChoice? = nil) -> ImportedPhoto {
        ImportedPhoto.fixture(roleChoice: roleChoice, assetID: assetID)
    }

    private func captured(_ photos: [ImportedPhoto]) -> [UUID: PhotoRoleChoice?] {
        Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.roleChoice) })
    }

    private func suggestions(_ pairs: [(UUID, PhotoRole)]) -> [UUID: PhotoRolePolicy.Suggestion] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.0, .role($0.1)) })
    }

    private func choices(
        _ photos: [ImportedPhoto],
        draft: [UUID: PhotoRoleDraft],
        suggestions: [UUID: PhotoRolePolicy.Suggestion] = [:]
    ) -> [UUID: PhotoRoleChoice] {
        PhotoRolesSheet.choices(
            photos: photos, draft: draft, capturedRoles: captured(photos), suggestions: suggestions
        )
    }

    private func hasChanges(
        _ photos: [ImportedPhoto],
        draft: [UUID: PhotoRoleDraft],
        suggestions: [UUID: PhotoRolePolicy.Suggestion] = [:]
    ) -> Bool {
        PhotoRolesSheet.hasChanges(
            photos: photos, draft: draft, capturedRoles: captured(photos), suggestions: suggestions
        )
    }

    // MARK: - Picker selection (a saved automatic role is never shown as a user pick)

    func testCapturedAutomaticPrimaryOnlyShowsAutomaticWhileAManualPrimaryShowsTheRole() {
        // The exact reported sequence: A was saved as an accepted automatic primary, then
        // the user picks B as a manual primary. A's policy role becomes supporting, and
        // its picker must stop showing "Primary" — it is an automatic choice, not the
        // user's pick.
        let automaticA = photo(roleChoice: .automatic(.primary))
        let manualB = photo()
        let photos = [automaticA, manualB]
        let draft: [UUID: PhotoRoleDraft] = [manualB.id: .role(.primary)]
        let capturedRoles = captured(photos)

        XCTAssertEqual(
            PhotoRolesSheet.pickerSelection(draft: draft, capturedRoles: capturedRoles, photo: manualB), .primary,
            "an explicit manual pick is the only thing shown as a specific role"
        )
        XCTAssertNil(
            PhotoRolesSheet.pickerSelection(draft: draft, capturedRoles: capturedRoles, photo: automaticA),
            "a captured automatic role must show Automatic, not its stored role"
        )

        let outcome = PhotoRolePolicy.suggest([
            PhotoRolePolicy.Candidate(assetID: automaticA.id, importIndex: 0, manualRole: nil,
                                      sceneScore: 0.9, analysisSucceeded: true, adequateSample: true, pixelArea: 1000),
            PhotoRolePolicy.Candidate(assetID: manualB.id, importIndex: 1, manualRole: .primary,
                                      sceneScore: 0.9, analysisSucceeded: true, adequateSample: true, pixelArea: 1000)
        ])
        let stored = PhotoRolePolicy.choices(
            candidates: [
                PhotoRolePolicy.Candidate(assetID: automaticA.id, importIndex: 0, manualRole: nil,
                                          sceneScore: 0.9, analysisSucceeded: true, adequateSample: true, pixelArea: 1000),
                PhotoRolePolicy.Candidate(assetID: manualB.id, importIndex: 1, manualRole: .primary,
                                          sceneScore: 0.9, analysisSucceeded: true, adequateSample: true, pixelArea: 1000)
            ],
            draft: draft, capturedRoles: capturedRoles, outcome: outcome
        )
        XCTAssertEqual(stored[manualB.id], .manual(.primary))
        XCTAssertEqual(stored[automaticA.id], .automatic(.supporting),
                       "the previously automatic primary is refreshed to supporting")
        XCTAssertEqual(stored.values.filter { $0.role == .primary }.count, 1,
                       "the界面 and the saved value agree: exactly one primary")
    }

    func testUntouchedCapturedManualChoiceStillShowsItsRole() {
        let manual = photo(roleChoice: .manual(.collageMaterial))
        let automatic = photo(roleChoice: .automatic(.supporting))
        let capturedRoles = captured([manual, automatic])
        XCTAssertEqual(
            PhotoRolesSheet.pickerSelection(draft: [:], capturedRoles: capturedRoles, photo: manual), .collageMaterial,
            "an untouched manual choice keeps its role"
        )
        XCTAssertNil(
            PhotoRolesSheet.pickerSelection(draft: [:], capturedRoles: capturedRoles, photo: automatic),
            "an untouched automatic choice shows Automatic"
        )
    }

    func testExplicitAutomaticDraftAndExplicitManualDraftBothShowCorrectly() {
        let stored = photo(roleChoice: .manual(.primary))
        let capturedRoles = captured([stored])
        XCTAssertNil(PhotoRolesSheet.pickerSelection(draft: [stored.id: .automatic], capturedRoles: capturedRoles, photo: stored))
        XCTAssertEqual(
            PhotoRolesSheet.pickerSelection(draft: [stored.id: .role(.supporting)], capturedRoles: capturedRoles, photo: stored),
            .supporting
        )
        XCTAssertEqual(
            PhotoRolesSheet.pickerSelection(draft: [:], capturedRoles: capturedRoles, photo: stored), .primary,
            "the stored manual role is still shown before any draft"
        )
    }

    /// The same role changed from automatic to manual is a real, saveable change.
    func testSameRoleAutomaticToManualIsSaveable() {
        let stored = photo(roleChoice: .automatic(.primary))
        XCTAssertTrue(hasChanges([stored], draft: [stored.id: .role(.primary)]))
        XCTAssertEqual(
            choices([stored], draft: [stored.id: .role(.primary)])[stored.id], .manual(.primary)
        )
    }

    // MARK: - Advice lines are honest about the source

    /// A role the policy derived from the user's saved manual choice is never called a
    /// device suggestion: it is described as following that choice.
    func testPolicyRoleConstrainedByAManualChoiceIsNotCalledASuggestion() {
        let manual = photo(roleChoice: .manual(.primary))
        let other = photo()
        // Named `capturedRoles`, not `captured`: a local named `captured` shadows the
        // `captured(...)` helper below and makes later `captured([...])` calls fail to
        // compile as "cannot call value of non-function type".
        let capturedRoles = captured([manual, other])
        // The picker keeps the manual role, and the row's advice must not present the
        // stored manual role as a device suggestion.
        XCTAssertEqual(
            PhotoRolesSheet.pickerSelection(draft: [:], capturedRoles: capturedRoles, photo: manual), .primary
        )
        XCTAssertEqual(PhotoRolesSheet.advice(for: manual, draft: [:], capturedRoles: capturedRoles,
                                              suggestion: .role(.primary)),
                       .keptManualChoice(.primary))
        XCTAssertEqual(PhotoRolesSheet.advice(for: other, draft: [:], capturedRoles: capturedRoles,
                                              suggestion: .role(.supporting)),
                       .suggestion(.supporting))
    }

    func testAdviceForExplicitAndFailedCases() {
        let stored = photo(roleChoice: .automatic(.primary))
        let storedRoles = captured([stored])
        XCTAssertEqual(PhotoRolesSheet.advice(for: stored, draft: [stored.id: .role(.supporting)],
                                              capturedRoles: storedRoles, suggestion: .role(.primary)),
                       PhotoRolesSheet.Advice.none)
        XCTAssertEqual(PhotoRolesSheet.advice(for: stored, draft: [stored.id: .automatic],
                                              capturedRoles: storedRoles, suggestion: .role(.primary)),
                       .suggestion(.primary))

        let failed = photo()
        XCTAssertEqual(PhotoRolesSheet.advice(for: failed, draft: [:],
                                              capturedRoles: captured([failed]), suggestion: .failed),
                       .noEvidence(keepingManualChoice: nil))
        let failedManual = photo(roleChoice: .manual(.supporting))
        XCTAssertEqual(PhotoRolesSheet.advice(for: failedManual, draft: [:],
                                              capturedRoles: captured([failedManual]), suggestion: .failed),
                       .noEvidence(keepingManualChoice: .supporting))
    }

    // MARK: - Deriving a save

    func testManualDraftIsStoredAsManualAndBeatsTheSuggestion() {
        let manual = photo()
        let suggested = photo()
        let result = choices(
            [manual, suggested],
            draft: [manual.id: .role(.excluded)],
            suggestions: suggestions([(manual.id, .primary), (suggested.id, .supporting)])
        )
        XCTAssertEqual(result[manual.id], .manual(.excluded))
        XCTAssertEqual(result[suggested.id], .automatic(.supporting))
    }

    func testAnUntouchedSavedManualChoiceKeepsItsSource() {
        let stored = photo(roleChoice: .manual(.primary))
        let result = choices([stored], draft: [:], suggestions: suggestions([(stored.id, .supporting)]))
        XCTAssertEqual(result[stored.id], .manual(.primary),
                       "a saved manual choice is not re-ranked by an untouched pass")
    }

    /// An untouched saved `automatic` choice is not a manual decision: it takes part
    /// in recomputation and is refreshed on the next explicit Save.
    func testAnUntouchedSavedAutomaticChoiceIsRefreshedInsteadOfFrozen() {
        let stored = photo(roleChoice: .automatic(.primary))
        let refreshed = choices([stored], draft: [:], suggestions: suggestions([(stored.id, .supporting)]))
        XCTAssertEqual(refreshed[stored.id], .automatic(.supporting))

        let cleared = choices([stored], draft: [:], suggestions: [:])
        XCTAssertTrue(cleared.isEmpty, "no fresh evidence clears the stale automatic choice")
    }

    // MARK: - Explicit Automatic

    func testExplicitAutomaticClearsASavedManualChoice() {
        let stored = photo(roleChoice: .manual(.collageMaterial))
        XCTAssertTrue(choices([stored], draft: [stored.id: .automatic], suggestions: [:]).isEmpty)
    }

    func testExplicitAutomaticStoresThisPassesFreshSuggestion() {
        let stored = photo(roleChoice: .manual(.primary))
        let result = choices(
            [stored], draft: [stored.id: .automatic], suggestions: suggestions([(stored.id, .supporting)])
        )
        XCTAssertEqual(result[stored.id], .automatic(.supporting))
    }

    // MARK: - Change detection compares role AND source

    func testNothingToSaveWhenTheCapturedStateAlreadyMatches() {
        let stored = photo(roleChoice: .manual(.primary))
        XCTAssertFalse(hasChanges([stored], draft: [:]))
        XCTAssertFalse(hasChanges([stored], draft: [stored.id: .role(.primary)]))
    }

    /// Automatic supporting → the user explicitly picks manual supporting: the role
    /// is identical, only the source changes, and that must be saveable.
    func testSourceOnlyChangeIsSaveable() {
        let stored = photo(roleChoice: .automatic(.supporting))
        XCTAssertTrue(hasChanges([stored], draft: [stored.id: .role(.supporting)]))
        XCTAssertEqual(
            choices([stored], draft: [stored.id: .role(.supporting)])[stored.id], .manual(.supporting)
        )
    }

    func testFreshAutomaticRoleOrClearFromRecomputeIsSaveable() {
        let stored = photo(roleChoice: .automatic(.primary))
        XCTAssertTrue(hasChanges([stored], draft: [:], suggestions: suggestions([(stored.id, .supporting)])))
        XCTAssertTrue(hasChanges([stored], draft: [:], suggestions: [:]))

        let fresh = photo()
        XCTAssertTrue(hasChanges([fresh], draft: [:], suggestions: suggestions([(fresh.id, .primary)])))
        XCTAssertFalse(hasChanges([fresh], draft: [:]), "no stored choice and no suggestion is nothing to save")
    }

    // MARK: - Shared effective manual role

    func testEffectiveManualRoleOnlyKeepsACapturedManualChoice() {
        let manual = photo(roleChoice: .manual(.primary))
        let automatic = photo(roleChoice: .automatic(.primary))
        let capturedRoles = captured([manual, automatic])

        XCTAssertEqual(
            PhotoRoleDraft.effectiveManualRole(draft: [:], capturedRoles: capturedRoles, assetID: manual.id),
            .primary
        )
        XCTAssertNil(
            PhotoRoleDraft.effectiveManualRole(draft: [:], capturedRoles: capturedRoles, assetID: automatic.id),
            "a saved automatic choice is not a manual decision"
        )
        XCTAssertNil(
            PhotoRoleDraft.effectiveManualRole(
                draft: [manual.id: .automatic], capturedRoles: capturedRoles, assetID: manual.id
            ),
            "explicit Automatic opens the photo to recomputation"
        )
        XCTAssertEqual(
            PhotoRoleDraft.effectiveManualRole(
                draft: [manual.id: .role(.supporting)], capturedRoles: capturedRoles, assetID: manual.id
            ),
            .supporting
        )
    }

    // MARK: - Promoting another primary

    func testPromotingAnotherPhotoDemotesAnUntouchedSavedManualPrimary() {
        let first = photo(roleChoice: .manual(.primary))
        let second = photo()
        let photos = [first, second]

        // The user only picks the second photo as primary; the first was never touched
        // in this sheet but must still give way, or Save would produce two primaries.
        let draft = PhotoRoleDraft.demotingOtherPrimaries(
            in: [second.id: .role(.primary)],
            capturedRoles: captured(photos),
            photos: photos,
            promoting: second.id
        )
        XCTAssertEqual(draft[first.id], .role(.supporting))

        let result = PhotoRolesSheet.choices(
            photos: photos, draft: draft, capturedRoles: captured(photos), suggestions: [:]
        )
        XCTAssertEqual(result[first.id], .manual(.supporting))
        XCTAssertEqual(result[second.id], .manual(.primary))
        XCTAssertEqual(result.values.filter { $0.role == .primary }.count, 1)
    }

    func testPromotingDoesNotTouchAnAutomaticPrimary() {
        let first = photo(roleChoice: .automatic(.primary))
        let second = photo()
        let photos = [first, second]
        let draft = PhotoRoleDraft.demotingOtherPrimaries(
            in: [second.id: .role(.primary)],
            capturedRoles: captured(photos),
            photos: photos,
            promoting: second.id
        )
        XCTAssertNil(draft[first.id], "an automatic primary is not a manual decision to demote")
        let result = PhotoRolesSheet.choices(
            photos: photos, draft: draft, capturedRoles: captured(photos), suggestions: [:]
        )
        XCTAssertNil(result[first.id] ?? nil)
        XCTAssertEqual(result[second.id], .manual(.primary))
    }

    // MARK: - "Use suggested roles"

    /// The button puts every photo into this pass's automatic draft, so a stored
    /// manual choice is visibly replaced by the suggestion and the label is honest —
    /// and Cancel still writes nothing.
    func testUseSuggestedRolesReplacesStoredManualDraftsWithAutomaticDrafts() {
        let stored = photo(roleChoice: .manual(.primary))
        let fresh = photo()
        let photos = [stored, fresh]
        let useSuggested: [UUID: PhotoRoleDraft] = Dictionary(
            uniqueKeysWithValues: photos.map { ($0.id, .automatic) }
        )
        XCTAssertTrue(hasChanges(photos, draft: useSuggested, suggestions: suggestions([(fresh.id, .supporting)])))

        let result = PhotoRolesSheet.choices(
            photos: photos,
            draft: useSuggested,
            capturedRoles: captured(photos),
            suggestions: suggestions([(stored.id, .supporting), (fresh.id, .supporting)])
        )
        XCTAssertEqual(result[stored.id], .automatic(.supporting))
        XCTAssertEqual(result[fresh.id], .automatic(.supporting))
    }
}
