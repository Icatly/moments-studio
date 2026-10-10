import Foundation

/// What the user has decided for one photo inside the Photo roles sheet.
///
/// Three real states, so "I never touched this" can never be confused with "I chose
/// Automatic":
/// * `absent` — untouched, so the **captured** saved value is kept;
/// * `automatic` — the user explicitly chose Automatic, which clears the saved
///   choice (or refreshes it from this pass's suggestion);
/// * `role` — the user chose a specific role and it is saved as `manual`.
///
/// This is the one value type the sheet's picker, its candidate inputs, its
/// change-detection and its Save all go through, so a test that drives this type is
/// driving the real interaction. It is deliberately **not** `Codable`: nothing here
/// is persisted.
enum PhotoRoleDraft: Equatable {
    case absent
    case automatic
    case role(PhotoRole)

    /// The draft chosen for one photo.
    static func value(in draft: [UUID: PhotoRoleDraft], for assetID: UUID) -> PhotoRoleDraft {
        draft[assetID] ?? .absent
    }

    /// The manual role the policy must respect for this photo, or `nil` when the
    /// draft leaves it open (untouched or explicitly Automatic).
    ///
    /// Only a captured **manual** choice is kept. A captured `automatic` choice is
    /// *not* a user decision: it takes part in recomputation and is refreshed when
    /// the user explicitly saves again.
    static func effectiveManualRole(
        draft: [UUID: PhotoRoleDraft],
        capturedRoles: [UUID: PhotoRoleChoice?],
        assetID: UUID
    ) -> PhotoRole? {
        switch value(in: draft, for: assetID) {
        case .absent:
            // An untouched photo keeps its captured **manual** role for this pass, so
            // an old sheet cannot silently re-rank the user's own decision. A captured
            // `automatic` value is not manual and stays open to recomputation.
            guard let captured = capturedRoles[assetID] ?? nil, captured.source == .manual else {
                return nil
            }
            return captured.role
        case .automatic:
            return nil
        case .role(let role):
            return role
        }
    }

    /// Demotes every manual primary other than `promoted` to a manual supporting
    /// photo, as the approved contract requires: a package may hold at most one saved
    /// primary, and a previously saved manual primary must give way when the user
    /// promotes another photo — even when it was never touched in this sheet.
    static func demotingOtherPrimaries(
        in draft: [UUID: PhotoRoleDraft],
        capturedRoles: [UUID: PhotoRoleChoice?],
        photos: [ImportedPhoto],
        promoting promoted: UUID
    ) -> [UUID: PhotoRoleDraft] {
        var result = draft
        for photo in photos where photo.id != promoted {
            guard effectiveManualRole(draft: draft, capturedRoles: capturedRoles, assetID: photo.id) == .primary else {
                continue
            }
            result[photo.id] = .role(.supporting)
        }
        return result
    }
}
