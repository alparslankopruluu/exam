import Foundation

struct DailyPlanEngine {
    func build(
        weakSkills: [MasterySnapshot],
        dueSkills: [MasterySnapshot],
        errorDNA: [ErrorDNAItem],
        dailyMinutes: Int
    ) -> [PlanTask] {
        let budget = min(max(dailyMinutes, 10), 180)
        var tasks: [PlanTask] = []
        var used = 0

        for skill in dueSkills.prefix(2) {
            let minutes = 6
            guard used + minutes <= budget else { continue }
            tasks.append(
                PlanTask(
                    type: "review",
                    skillId: skill.skillId,
                    title: "Review \(skill.skillId)",
                    estimatedMinutes: minutes,
                    priority: 1.0 + (1.0 - skill.score)
                )
            )
            used += minutes
        }

        for skill in weakSkills where !tasks.contains(where: { $0.skillId == skill.skillId }) {
            guard tasks.filter({ $0.type == "practice" }).count < 3 else { break }
            let minutes = 8
            guard used + minutes <= budget else { continue }
            tasks.append(
                PlanTask(
                    type: "practice",
                    skillId: skill.skillId,
                    title: "Practice \(skill.skillId)",
                    estimatedMinutes: minutes,
                    priority: 0.9 + (1.0 - skill.score)
                )
            )
            used += minutes
        }

        if let error = errorDNA.first, used + 6 <= budget {
            tasks.append(
                PlanTask(
                    type: "mistake_review",
                    skillId: error.skillId,
                    title: "Fix \(error.errorType) mistakes",
                    estimatedMinutes: 6,
                    priority: 1.2 + Double(error.count) / 10
                )
            )
            used += 6
        }

        if tasks.isEmpty {
            let minutes = min(10, budget)
            tasks.append(
                PlanTask(
                    type: "quick_practice",
                    skillId: nil,
                    title: "Quick mixed practice",
                    estimatedMinutes: minutes,
                    priority: 1
                )
            )
            used += minutes
        }

        if budget - used >= 12 {
            tasks.append(
                PlanTask(
                    type: "mixed_set",
                    skillId: nil,
                    title: "Mixed exam set",
                    estimatedMinutes: min(15, budget - used),
                    priority: 0.6
                )
            )
        }

        return tasks.sorted { $0.priority > $1.priority }
    }
}
