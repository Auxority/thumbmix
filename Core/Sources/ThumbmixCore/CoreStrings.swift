import Foundation

/// The package's own string table: labels the app shows come from here, so they can be translated
/// in `Resources/Localizable.xcstrings`. OSC addresses never go through it.
enum CoreStrings {
    static let bundle = Bundle.module

    static func text(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle)
    }
}
