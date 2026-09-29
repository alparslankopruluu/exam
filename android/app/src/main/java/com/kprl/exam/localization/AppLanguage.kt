package com.kprl.exam.localization

import java.util.Locale

/** The 20 languages the app ships, keyed by locale file name in content/locales. */
object AppLanguage {
    val supported: List<Pair<String, String>> = listOf(
        "en" to "English", "tr" to "Türkçe", "de" to "Deutsch", "fr" to "Français",
        "es" to "Español", "it" to "Italiano", "pt" to "Português (Brasil)", "pt-PT" to "Português (Portugal)",
        "nl" to "Nederlands", "sv" to "Svenska", "nb" to "Norsk", "pl" to "Polski",
        "ru" to "Русский", "ar" to "العربية", "hi" to "हिन्दी", "id" to "Bahasa Indonesia",
        "ja" to "日本語", "ko" to "한국어", "zh-Hans" to "简体中文", "zh-Hant" to "繁體中文"
    )

    private val codes = supported.map { it.first }.toSet()

    /** Maps a device locale to the closest shipped language. */
    fun resolve(locale: Locale = Locale.getDefault()): String {
        val language = locale.language.ifBlank { "en" }
        return when (language) {
            "zh" -> if (locale.script == "Hant" || locale.country in setOf("TW", "HK", "MO")) "zh-Hant" else "zh-Hans"
            "pt" -> if (locale.country == "PT") "pt-PT" else "pt"
            "nb", "no", "nn" -> "nb"
            // Older Android reports Indonesian as the legacy "in" code.
            "in" -> "id"
            else -> if (language in codes) language else "en"
        }
    }

    fun isRightToLeft(code: String): Boolean = code == "ar"
}
