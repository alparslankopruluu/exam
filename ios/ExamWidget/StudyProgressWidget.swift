import SwiftUI
import WidgetKit

struct StudyProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StudyProgressWidget", provider: SnapshotProvider()) { entry in
            StudyProgressView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Study progress")
        .description("Streak, today's plan and reviews due.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct StudyProgressView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("🔥 \(s.streak) \(s.labels.streak)").font(.headline)
                Text("\(s.tasksCompleted)/\(s.tasksTotal) \(s.labels.tasksDone)")
                if s.dueReviews > 0 {
                    Text("\(s.dueReviews) \(s.labels.reviewsDue)")
                }
            }
            .widgetURL(URL(string: "exam://today"))
        case .systemMedium:
            HStack(spacing: 14) {
                streakBlock
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    progressRow
                    if s.dueReviews > 0 {
                        Link(destination: URL(string: "exam://review")!) {
                            Label("\(s.dueReviews) \(s.labels.reviewsDue)", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(WidgetPalette.amber)
                        }
                    }
                    Text(s.nextTaskTitle ?? s.labels.allDone)
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(2)
                }
            }
            .widgetURL(URL(string: "exam://today"))
        default:
            VStack(alignment: .leading, spacing: 10) {
                streakBlock
                Spacer(minLength: 0)
                progressRow
            }
            .widgetURL(URL(string: "exam://today"))
        }
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.examName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(WidgetPalette.primary)
            Text("🔥 \(s.streak)")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(WidgetPalette.textPrimary)
            Text(s.labels.streak)
                .font(.system(size: 11))
                .foregroundStyle(WidgetPalette.textSecondary)
        }
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(s.tasksCompleted)/\(s.tasksTotal) \(s.labels.tasksDone)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetPalette.textPrimary)
            ProgressView(value: Double(s.tasksCompleted), total: Double(max(s.tasksTotal, 1)))
                .tint(WidgetPalette.mint)
        }
    }
}
