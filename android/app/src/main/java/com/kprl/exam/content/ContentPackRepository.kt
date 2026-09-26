package com.kprl.exam.content

import android.content.Context
import org.json.JSONObject

data class ContentUnit(
    val id: String,
    val title: String,
    val durationMinutes: Int?,
    val questionCount: Int?
)

data class ExamContentPack(
    val id: String,
    val displayName: String,
    val units: List<ContentUnit>
)

object ContentPackRepository {
    fun load(context: Context, packId: String): ExamContentPack? {
        return runCatching {
            val path = "packs/$packId.json"
            val raw = context.assets.open(path).bufferedReader().use { it.readText() }
            val json = JSONObject(raw)
            val units = mutableListOf<ContentUnit>()

            json.optJSONArray("sections")?.let { sections ->
                for (index in 0 until sections.length()) {
                    val item = sections.getJSONObject(index)
                    units += ContentUnit(
                        id = item.optString("id", "section_$index"),
                        title = item.optString("title", "Section ${index + 1}"),
                        durationMinutes = item.optInt("durationMinutes").takeIf { item.has("durationMinutes") },
                        questionCount = item.optInt("questionCount").takeIf { item.has("questionCount") }
                    )
                }
            }

            if (units.isEmpty()) {
                json.optJSONArray("sessions")?.let { sessions ->
                    for (index in 0 until sessions.length()) {
                        val item = sessions.getJSONObject(index)
                        units += ContentUnit(
                            id = item.optString("id", "session_$index"),
                            title = item.optString("title", "Session ${index + 1}"),
                            durationMinutes = null,
                            questionCount = null
                        )
                    }
                }
            }

            ExamContentPack(
                id = json.getString("id"),
                displayName = json.optString("displayName", packId),
                units = units
            )
        }.getOrNull()
    }
}
