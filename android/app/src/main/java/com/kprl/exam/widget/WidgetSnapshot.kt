package com.kprl.exam.widget

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Data the app prepares for the home-screen widgets. Labels are already
 * localized so the widgets do not load locale files.
 */
data class WidgetSnapshot(
    val examName: String,
    val streak: Int,
    val tasksCompleted: Int,
    val tasksTotal: Int,
    val dueReviews: Int,
    val nextTaskTitle: String?,
    val question: Question?,
    val labels: Map<String, String>
) {
    data class Question(
        val id: String,
        val topic: String,
        val prompt: String,
        val options: List<String>,
        val correctIndex: Int,
        val explanation: String
    )

    fun label(key: String) = labels[key].orEmpty()

    fun toJson(): String = JSONObject().apply {
        put("examName", examName)
        put("streak", streak)
        put("tasksCompleted", tasksCompleted)
        put("tasksTotal", tasksTotal)
        put("dueReviews", dueReviews)
        put("nextTaskTitle", nextTaskTitle)
        question?.let { q ->
            put("question", JSONObject().apply {
                put("id", q.id)
                put("topic", q.topic)
                put("prompt", q.prompt)
                put("options", JSONArray(q.options))
                put("correctIndex", q.correctIndex)
                put("explanation", q.explanation)
            })
        }
        put("labels", JSONObject(labels))
    }.toString()

    companion object {
        private const val PREFS = "exam_widget"
        private const val KEY_SNAPSHOT = "snapshot"
        private const val KEY_ANSWER_ID = "answer_id"
        private const val KEY_ANSWER_CHOICE = "answer_choice"

        private fun prefs(context: Context) =
            context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun load(context: Context): WidgetSnapshot? {
            val raw = prefs(context).getString(KEY_SNAPSHOT, null) ?: return null
            return runCatching { fromJson(JSONObject(raw)) }.getOrNull()
        }

        fun save(context: Context, snapshot: WidgetSnapshot) {
            prefs(context).edit().putString(KEY_SNAPSHOT, snapshot.toJson()).apply()
        }

        /** The option chosen in the widget; a new question starts unanswered. */
        fun answer(context: Context, questionId: String): Int? {
            val prefs = prefs(context)
            if (prefs.getString(KEY_ANSWER_ID, null) != questionId) return null
            return prefs.getInt(KEY_ANSWER_CHOICE, -1).takeIf { it >= 0 }
        }

        fun saveAnswer(context: Context, questionId: String, choice: Int) {
            prefs(context).edit()
                .putString(KEY_ANSWER_ID, questionId)
                .putInt(KEY_ANSWER_CHOICE, choice)
                .apply()
        }

        private fun fromJson(json: JSONObject): WidgetSnapshot {
            val question = json.optJSONObject("question")?.let { q ->
                val options = q.getJSONArray("options")
                Question(
                    id = q.getString("id"),
                    topic = q.getString("topic"),
                    prompt = q.getString("prompt"),
                    options = List(options.length()) { options.getString(it) },
                    correctIndex = q.getInt("correctIndex"),
                    explanation = q.getString("explanation")
                )
            }
            val labelsJson = json.getJSONObject("labels")
            return WidgetSnapshot(
                examName = json.getString("examName"),
                streak = json.getInt("streak"),
                tasksCompleted = json.getInt("tasksCompleted"),
                tasksTotal = json.getInt("tasksTotal"),
                dueReviews = json.getInt("dueReviews"),
                nextTaskTitle = json.optString("nextTaskTitle").takeIf { it.isNotEmpty() && it != "null" },
                question = question,
                labels = labelsJson.keys().asSequence().associateWith { labelsJson.getString(it) }
            )
        }
    }
}
