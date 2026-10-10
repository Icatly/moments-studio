import CoreGraphics
import Foundation

/// Why one role-save request was refused.
///
/// Typed instead of a generic failure, because the sheet has to react differently:
/// a stale request asks the user to reload, a busy request means another mutation
/// owns the single mutation gate, and a write failure keeps the draft for a retry.
enum PhotoRoleSaveError: Error, Equatable, Sendable {
    /// The project is not available in this session any more.
    case projectMissing
    /// A photo was added, removed, or its stored metadata changed after the sheet
    /// snapshotted it, so the choices no longer describe this package.
    case photosChanged
    /// A saved choice is impossible (unknown combination or more than one primary).
    case impossible(String)
    /// Another mutation is in flight.
    case busy
}
