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
            val normalized = languageCode.substringBefore("-").lowercase()
            val localized = if (normalized == "en") fallback else read(normalized)
            return LocalizedCopy(localized, fallback)
        }
    }
}
