package com.kprl.exam.localization

import android.content.Context
import org.json.JSONObject

class LocalizedCopy private constructor(
    private val values: Map<String, String>,
    private val fallback: Map<String, String>
) {
    fun text(key: String, variables: Map<String, String> = emptyMap()): String {
        var value = values[key] ?: fallback[key] ?: key
        variables.forEach { (name, replacement) ->
            value = value.replace("{$name}", replacement)
        }
        return value
    }

    companion object {
        fun load(context: Context, languageCode: String): LocalizedCopy {
            fun read(code: String): Map<String, String> = runCatching {
                val raw = context.assets.open("locales/$code.json").bufferedReader().use { it.readText() }
                val json = JSONObject(raw)
                json.keys().asSequence().associateWith { key -> json.getString(key) }
            }.getOrDefault(emptyMap())

            val fallback = read("en")
            // Exact file first (pt-PT, zh-Hant), then the base language, then English.
            val base = languageCode.substringBefore("-").lowercase()
            val exact = if (languageCode == "en") emptyMap() else read(languageCode)
            val localized = exact.ifEmpty { if (base == "en") fallback else read(base) }
            return LocalizedCopy(localized, fallback)
        }
    }
}
