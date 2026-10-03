import Foundation
import SwiftUI

/// The 20 languages the app ships, keyed by locale file name in content/locales.
enum AppLanguage {
    static let supported: [(code: String, name: String)] = [
        ("en", "English"), ("tr", "Türkçe"), ("de", "Deutsch"), ("fr", "Français"),
        ("es", "Español"), ("it", "Italiano"), ("pt", "Português (Brasil)"), ("pt-PT", "Português (Portugal)"),
        ("nl", "Nederlands"), ("sv", "Svenska"), ("nb", "Norsk"), ("pl", "Polski"),
        ("ru", "Русский"), ("ar", "العربية"), ("hi", "हिन्दी"), ("id", "Bahasa Indonesia"),
        ("ja", "日本語"), ("ko", "한국어"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文")
    ]

    private static let codes = Set(supported.map(\.code))

    /// Maps a device locale to the closest shipped language. Defaults to the user's first
    /// preferred language: `Locale.current` follows the bundle's localizations and can report
    /// English (e.g. "en_TR") even on a Turkish device.
    static func resolve(_ locale: Locale = Locale(identifier: Locale.preferredLanguages.first ?? "en")) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? ""
        let script = locale.language.script?.identifier ?? ""

        switch language {
        case "zh":
            return script == "Hant" || ["TW", "HK", "MO"].contains(region) ? "zh-Hant" : "zh-Hans"
        case "pt":
            return region == "PT" ? "pt-PT" : "pt"
        case "nb", "no", "nn":
            return "nb"
        default:
            return codes.contains(language) ? language : "en"
        }
    }

    static func isRightToLeft(_ code: String) -> Bool {
        code == "ar"
    }

    static func layoutDirection(for code: String) -> LayoutDirection {
        isRightToLeft(code) ? .rightToLeft : .leftToRight
    }
}
