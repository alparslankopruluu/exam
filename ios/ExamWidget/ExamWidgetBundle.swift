import SwiftUI
import WidgetKit
import ActivityKit

@main
struct ExamWidgetBundle: WidgetBundle {
    var body: some Widget {
        StudyProgressWidget()
        DailyQuestionWidget()
        FocusLiveActivity()
    }
}

enum WidgetPalette {
    static let background = Color(red: 247/255, green: 249/255, blue: 252/255)
    static let textPrimary = Color(red: 15/255, green: 23/255, blue: 42/255)
    static let textSecondary = Color(red: 100/255, green: 116/255, blue: 139/255)
    static let primary = Color(red: 59/255, green: 108/255, blue: 246/255)
    static let mint = Color(red: 44/255, green: 203/255, blue: 140/255)
    static let amber = Color(red: 245/255, green: 165/255, blue: 36/255)
    static let coral = Color(red: 242/255, green: 109/255, blue: 109/255)
    static let border = Color(red: 230/255, green: 234/255, blue: 242/255)
    static let softBlue = Color(red: 234/255, green: 241/255, blue: 255/255)
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let answer: Int?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder, answer: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // The app reloads timelines whenever data changes; midnight refresh
        // clears yesterday's answer state.
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry()], policy: .after(tomorrow)))
    }

    private func entry() -> SnapshotEntry {
        let snapshot = WidgetSnapshot.load() ?? .placeholder
        let answer = snapshot.question.flatMap { WidgetSnapshot.answer(for: $0.id) }
        return SnapshotEntry(date: .now, snapshot: snapshot, answer: answer)
    }
}

/// Lock screen and Dynamic Island countdown for a focus session.
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.37, green: 0.66, blue: 0.50))
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.91, green: 0.97, blue: 0.93))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text("Examly · \(context.attributes.exam)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
            }
            .padding(16)
            .activityBackgroundTint(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill").foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 64)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.title).font(.system(size: 13, weight: .semibold))
                }
            } compactLeading: {
                Image(systemName: "leaf.fill").foregroundStyle(.green)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "leaf.fill").foregroundStyle(.green)
            }
        }
    }
}

