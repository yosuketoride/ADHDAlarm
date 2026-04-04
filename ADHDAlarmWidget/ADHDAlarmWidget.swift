import WidgetKit
import SwiftUI
import AppIntents
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

    // MARK: - App Group Data
    private var owlName: String {
        UserDefaults(suiteName: "group.com.yosuke.WasurenboAlarm")?.string(forKey: "owl_name") ?? "ふくろう"
    }
    
    private var owlXP: Int {
        UserDefaults(suiteName: "group.com.yosuke.WasurenboAlarm")?.integer(forKey: "owl_xp") ?? 0
    }

    /// XP × 状況に応じたふくろう画像名を返す（ウィジェット用・4感情）
    private func owlImageName(for alarm: WidgetAlarmEvent?) -> String {
        let stage: Int
        switch owlXP {
        case 0..<100:    stage = 0
        case 100..<500:  stage = 1
        case 500..<1000: stage = 2
        default:         stage = 3
        }
        let emotion: String
        guard let alarm = alarm else {
            emotion = "sleepy"
            return "owl_stage\(stage)_\(emotion)"
        }
        let minutes = Int(alarm.fireDate.timeIntervalSinceNow / 60)
        if minutes < 10 {
            emotion = "worried"
        } else if minutes > 60 {
            emotion = "sleepy"
        } else {
            emotion = "normal"
        }
        return "owl_stage\(stage)_\(emotion)"
    }

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

    // Small: ふくろう大きく表示 + 時刻 + タイトル
    private func smallView(alarm: WidgetAlarmEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // ふくろう + 残り時間バッジ
            HStack(alignment: .top, spacing: 0) {
                Image(owlImageName(for: alarm))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(alarm.fireDate.remainingString)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.blue, in: Capsule())
                    Text(alarm.fireDate.widgetTimeString)
                        .font(.title3.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }

            Spacer(minLength: 0)

            // タイトル（下部に大きく）
            Text(alarm.title)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 完了ボタン
            Button(intent: CompleteAlarmIntent(eventID: alarm.id.uuidString)) {
                Text("完了")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.green)
            .controlSize(.mini)
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // Medium: ふくろうの部屋 + 予定情報 + 完了ボタン
    private func mediumView(alarm: WidgetAlarmEvent) -> some View {
        HStack(spacing: 0) {
            // 左ペイン（1/3）: ふくろうの部屋（箱庭）
            owlRoomView(alarm: alarm)
                .frame(maxWidth: 140)
            
            // 右ペイン（2/3）: 予定情報 + 完了ボタン
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(alarm.fireDate.widgetTimeString)
                        .font(.title.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                    
                    Spacer()
                    
                    Text(alarm.fireDate.remainingString)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }

                Text(alarm.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                Button(intent: CompleteAlarmIntent(eventID: alarm.id.uuidString)) {
                    Text("完了")
                        .font(.caption)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.green)
                .controlSize(.small)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func owlRoomView(alarm: WidgetAlarmEvent?) -> some View {
        let xp = owlXP
        let isSleepy = alarm == nil || alarm!.fireDate.timeIntervalSinceNow > 3600
        let isWorried = alarm != nil && alarm!.fireDate.timeIntervalSinceNow < 600

        return ZStack {
            // Layer 1: 背景レイヤー (後日画像アセットに差し替え可能)
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Color(isSleepy ? .gray : .orange).opacity(0.2)
                    Color.brown.opacity(0.3).frame(height: geo.size.height * 0.4)
                }
            }
            .ignoresSafeArea()

            // Layer 2: アイテムアイコン
            ZStack {
                if xp >= 100 { Text("🪵").font(.system(size: 30)).offset(x: -25, y: -20) } // 本棚 奥
                if xp >= 300 { Text("🪴").font(.system(size: 24)).offset(x: 30, y: 15) }   // 観葉植物 手前
                if xp >= 700 { Text("🕯️").font(.system(size: 20)).offset(x: -15, y: -5) }  // ランプ
                if xp >= 1000 { Text("🔭").font(.system(size: 28)).offset(x: 20, y: -15) } // 望遠鏡 奥
            }

            // Layer 3: ふくろうキャラ
            Image(owlImageName(for: alarm))
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .offset(x: isWorried ? -8 : 0, y: 6)
        }
    }

    // Large: 今日の予定一覧
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー（ふくろう + タイトル + 日付 + マイクボタン）
            HStack(spacing: 8) {
                Image(owlImageName(for: entry.nextAlarm))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                Text("今日の予定")
                    .font(.headline.weight(.bold))
                Spacer()
                Text(Date().widgetDateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "adhdalarm://voice-input")!) {
                    Image(systemName: "mic.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 8)

            if entry.todayAlarms.isEmpty {
                // 今日の予定なし
                VStack(spacing: 12) {
                    Image(owlImageName(for: nil))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
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
                    .frame(minWidth: 44, alignment: .trailing)
                // 完了インジケーター
                Image(systemName: isPast ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isPast ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                // タイトル
                Text(alarm.title)
                    .font(.callout)
                    .foregroundStyle(isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .strikethrough(isPast, color: .secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .layoutPriority(1)
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

    // 予定なし（タップで音声入力またはアプリを開く）
    private var emptyView: some View {
        VStack(spacing: 8) {
            owlRoomView(alarm: nil) // 簡易表示
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 10)
                .padding(.top, 10)

            Text("\(owlName)と一緒にのんびりしてね")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
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
