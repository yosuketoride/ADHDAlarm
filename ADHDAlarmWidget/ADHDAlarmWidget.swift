import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct NextAlarmEntry: TimelineEntry {
    let date: Date
    let nextAlarm: WidgetAlarmEvent?
    /// 大サイズウィジェット用: 今日の予定一覧
    let todayAlarms: [WidgetAlarmEvent]
}

// MARK: - Provider

struct NextAlarmProvider: TimelineProvider {

    private func makePlaceholderAlarm() -> WidgetAlarmEvent {
        WidgetAlarmEvent(
            id: UUID(),
            title: "お医者さん",
            fireDate: Date().addingTimeInterval(3600),
            preNotificationMinutes: 15,
            voiceCharacter: .femaleConcierge,
            createdAt: Date()
        )
    }

    func placeholder(in context: Context) -> NextAlarmEntry {
        let alarm = makePlaceholderAlarm()
        return NextAlarmEntry(date: Date(), nextAlarm: alarm, todayAlarms: [alarm])
    }

    func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) {
        let alarm = WidgetDataProvider.nextAlarm()
        let today = WidgetDataProvider.todayAlarmsAll()
        completion(NextAlarmEntry(date: Date(), nextAlarm: alarm, todayAlarms: today))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        let alarm = WidgetDataProvider.nextAlarm()
        let today = WidgetDataProvider.todayAlarmsAll()
        let entry = NextAlarmEntry(date: Date(), nextAlarm: alarm, todayAlarms: today)

        // 次のアラームの時刻に更新、なければ1時間後に再チェック
        let nextRefresh = alarm?.fireDate ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget View

struct NextAlarmWidgetView: View {
    let entry: NextAlarmEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemLarge {
            largeView
        } else if let alarm = entry.nextAlarm {
            switch family {
            case .systemMedium: mediumView(alarm: alarm)
            default:            smallView(alarm: alarm)
            }
        } else {
            emptyView
        }
    }

    // Small: 残り時間 + タイトル（高齢者向け大文字）
    private func smallView(alarm: WidgetAlarmEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(alarm.fireDate.remainingString)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.blue)

            Text(alarm.title)
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            Spacer()

            HStack(spacing: 4) {
                Text(alarm.fireDate.widgetDateLabel)
                Text(alarm.fireDate.widgetTimeString)
                    .fontWeight(.semibold)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // Medium: 時刻 + 残り時間 + タイトル + 他の件数
    private func mediumView(alarm: WidgetAlarmEvent) -> some View {
        HStack(spacing: 16) {
            // 左: 時刻
            VStack(alignment: .center, spacing: 4) {
                Text(alarm.fireDate.widgetTimeString)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)

                Text(alarm.fireDate.remainingString)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }
            .frame(maxWidth: 110)

            Divider()

            // 右: 予定情報
            VStack(alignment: .leading, spacing: 6) {
                Text(alarm.fireDate.widgetDateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(alarm.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                let others = WidgetDataProvider.todayAlarms().filter { $0.id != alarm.id }
                if !others.isEmpty {
                    Text("他\(others.count)件のご予定")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // Large: 今日の予定一覧
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .foregroundStyle(.blue)
                Text("今日の予定")
                    .font(.headline.weight(.bold))
                Spacer()
                Text(Date().widgetDateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 8)

            if entry.todayAlarms.isEmpty {
                // 今日の予定なし
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green.opacity(0.7))
                    Text("今日の予定はありません")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Link(destination: URL(string: "adhdalarm://voice-input")!) {
                        Label("予定を追加する", systemImage: "mic.circle.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 予定リスト（最大6件）
                let displayAlarms = Array(entry.todayAlarms.prefix(6))
                VStack(spacing: 0) {
                    ForEach(displayAlarms) { alarm in
                        alarmRow(alarm: alarm, isLast: alarm.id == displayAlarms.last?.id)
                    }

                    // 6件を超える場合の省略表示
                    if entry.todayAlarms.count > 6 {
                        HStack {
                            Spacer()
                            Text("他\(entry.todayAlarms.count - 6)件")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // 大サイズウィジェット用 行ビュー（ForEach内でletを使うと型推論が壊れるためヘルパー化）
    private func alarmRow(alarm: WidgetAlarmEvent, isLast: Bool) -> some View {
        let isPast = alarm.fireDate < Date()
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 時刻
                Text(alarm.fireDate.widgetTimeString)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.blue))
                    .frame(width: 44, alignment: .trailing)
                // 完了インジケーター
                Image(systemName: isPast ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isPast ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                // タイトル
                Text(alarm.title)
                    .font(.callout)
                    .foregroundStyle(isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .strikethrough(isPast, color: .secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isPast ? Color.clear : Color.blue.opacity(0.04))

            if !isLast {
                Divider().padding(.horizontal, 14)
            }
        }
    }

    // 予定なし（タップで音声入力画面を開く）
    private var emptyView: some View {
        Link(destination: URL(string: "adhdalarm://voice-input")!) {
            VStack(spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                Text("予定を追加する")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("タップして声で入力")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

// MARK: - Widget Definition

struct NextAlarmWidget: Widget {
    let kind = "NextAlarmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextAlarmProvider()) { entry in
            NextAlarmWidgetView(entry: entry)
        }
        .configurationDisplayName("次のご予定")
        .description("次にセットしたアラームをひと目で確認できます。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
