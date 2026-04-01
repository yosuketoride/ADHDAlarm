import WidgetKit
import SwiftUI

// MARK: - Visual Timer Widget（ロック画面 / スタンバイ対応）

struct VisualTimerEntry: TimelineEntry {
    let date: Date
    let nextAlarm: WidgetAlarmEvent?
}

struct VisualTimerProvider: TimelineProvider {

    func placeholder(in context: Context) -> VisualTimerEntry {
        VisualTimerEntry(
            date: Date(),
            nextAlarm: WidgetAlarmEvent(
                id: UUID(),
                title: "薬を飲む",
                fireDate: Date().addingTimeInterval(1800),
                preNotificationMinutes: 15,
                voiceCharacter: .femaleConcierge,
                createdAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VisualTimerEntry) -> Void) {
        completion(VisualTimerEntry(date: Date(), nextAlarm: WidgetDataProvider.nextAlarm()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VisualTimerEntry>) -> Void) {
        let alarm = WidgetDataProvider.nextAlarm()
        let entry = VisualTimerEntry(date: Date(), nextAlarm: alarm)
        let nextRefresh = alarm?.fireDate ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - View

struct VisualTimerWidgetView: View {
    let entry: VisualTimerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let alarm = entry.nextAlarm {
            switch family {
            case .accessoryCircular:    circularView(alarm: alarm)
            case .accessoryRectangular: rectangularView(alarm: alarm)
            default:                    rectangularView(alarm: alarm)
            }
        } else {
            noAlarmView
        }
    }

    // 円形ゲージ（ロック画面・スタンバイ）
    private func circularView(alarm: WidgetAlarmEvent) -> some View {
        let total = alarm.fireDate.timeIntervalSince(alarm.createdAt)
        let remaining = max(0, alarm.fireDate.timeIntervalSinceNow)
        let progress = total > 0 ? remaining / total : 0.0

        return Gauge(value: 1.0 - progress) {
            EmptyView()
        } currentValueLabel: {
            Text(alarm.fireDate.widgetTimeString)
                .font(.system(.caption2, design: .rounded).weight(.bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.blue)
        .containerBackground(.clear, for: .widget)
    }

    // 横長矩形（ロック画面）
    private func rectangularView(alarm: WidgetAlarmEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                Text(alarm.fireDate.widgetTimeString)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                Spacer()
                Text(alarm.fireDate.remainingString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(alarm.title)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var noAlarmView: some View {
        Image(systemName: "checkmark.circle")
            .font(.title2)
            .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Definition

struct VisualTimerWidget: Widget {
    let kind = "VisualTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VisualTimerProvider()) { entry in
            VisualTimerWidgetView(entry: entry)
        }
        .configurationDisplayName("残り時間ゲージ")
        .description("次のアラームまでの残り時間を表示します。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
