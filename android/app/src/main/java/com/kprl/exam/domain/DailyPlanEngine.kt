package com.kprl.exam.domain

import com.kprl.exam.platform.persistence.ErrorDNAItem
import com.kprl.exam.platform.persistence.MasterySnapshot
import com.kprl.exam.platform.persistence.PlanTask
import java.util.UUID

class DailyPlanEngine {
    fun build(
        weakSkills: List<MasterySnapshot>,
        dueSkills: List<MasterySnapshot>,
        errorDNA: List<ErrorDNAItem>,
        dailyMinutes: Int
    ): List<PlanTask> {
        val budget = dailyMinutes.coerceIn(10, 180)
        val tasks = mutableListOf<PlanTask>()
        var used = 0

        dueSkills.take(2).forEach { skill ->
            val minutes = 6
            if (used + minutes <= budget) {
                tasks += task(
                    "review",
                    skill.skillId,
                    "Review " + skill.skillId,
                    minutes,
                    1.0 + (1.0 - skill.score)
                )
                used += minutes
            }
        }

        weakSkills
            .filterNot { weak -> tasks.any { it.skillId == weak.skillId } }
            .take(3)
            .forEach { skill ->
                val minutes = 8
                if (used + minutes <= budget) {
                    tasks += task(
                        "practice",
                        skill.skillId,
                        "Practice " + skill.skillId,
                        minutes,
                        0.9 + (1.0 - skill.score)
                    )
                    used += minutes
                }
            }

        errorDNA.firstOrNull()?.let { error ->
            val minutes = 6
            if (used + minutes <= budget) {
                tasks += task(
                    "mistake_review",
                    error.skillId,
                    "Fix " + error.errorType + " mistakes",
                    minutes,
                    1.2 + error.count / 10.0
                )
                used += minutes
            }
        }

        if (tasks.isEmpty()) {
            tasks += task("quick_practice", null, "Quick mixed practice", minOf(10, budget), 1.0)
            used += minOf(10, budget)
        }

        if (budget - used >= 12) {
            tasks += task("mixed_set", null, "Mixed exam set", minOf(15, budget - used), 0.6)
        }

        return tasks.sortedByDescending { it.priority }
    }

    private fun task(
        type: String,
        skillId: String?,
        title: String,
        minutes: Int,
        priority: Double
    ) = PlanTask(
        id = UUID.randomUUID().toString(),
        type = type,
        skillId = skillId,
        title = title,
        estimatedMinutes = minutes,
        priority = priority
    )
}
