import Foundation

/// Temporary product identity.
///
/// The display name, bundle identifier and version are placeholders that must
/// be replaced before App Store submission (see `APP_STORE_REQUIREMENTS.md`).
/// No logic branches on these strings, so rebranding is a small change: this
/// file, the target name and the bundle identifier build setting.
enum AppInfo {
    /// Placeholder product name, shown on the Home screen and in Settings.
    static let displayName = "Moments Studio"

    /// Identifies the build during stage review.
    static let stageLabel = "Stage 01 · Foundation"

    /// `CFBundleShortVersionString` from the generated Info.plist.
    static let version = infoString(forKey: "CFBundleShortVersionString") ?? "unknown"

    /// `CFBundleVersion` from the generated Info.plist.
    static let build = infoString(forKey: "CFBundleVersion") ?? "unknown"

    /// Reads one string value from the app's Info.plist.
    ///
    /// Written as a helper rather than one inline `as? … ?? …` expression
    /// because the Swift grammar used by this project's static analysis does not
    /// accept an unparenthesized conditional cast followed by `??`. Parentheses
    /// or a helper both read fine; the helper keeps the call sites short.
    private static func infoString(forKey key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
