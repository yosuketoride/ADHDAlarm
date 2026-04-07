import Foundation

/// App GroupのJSONからAlarmEventを読み込むWidget専用ヘルパー
///
/// ⚠️ P-9-9 App Group Race Condition防止ルール:
/// Widget Extension は App Group から「読み取りのみ」行うこと。
/// XP加算等の書き込みはメインアプリ側でのみ行い、Widgetからは絶対に書き込まない。
/// メインアプリが書き込み後に WidgetCenter.shared.reloadAllTimelines() を呼ぶ。
enum WidgetDataProvider {

    private static let appGroupID = "group.com.yosuke.WasurenboAlarm"
    private static let fileName   = "alarm_events.json"

    /// App Groupコンテナからアラーム一覧を取得する（読み取りのみ）
    static func loadAll() -> [WidgetAlarmEvent] {
        guard
            let url  = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                .appendingPathComponent(fileName),
            let data = try? Data(contentsOf: url)
        else { return [] }

        return (try? JSONDecoder().decode([WidgetAlarmEvent].self, from: data)) ?? []
    }

    /// 直近の未来アラームを1件返す
    static func nextAlarm() -> WidgetAlarmEvent? {
        loadAll()
            .filter { $0.completionStatus == nil && $0.fireDate > Date() }
            .sorted { $0.fireDate < $1.fireDate }
            .first
    }

    /// 今日の未完了アラームをすべて返す（Medium ウィジェット用）
    /// 表示順：スケジュール済み（nil・未来）を先頭、反応待ち（awaitingResponse・今日中）を後ろに配置
    /// Medium widget は「次の予定」表示が主目的のため、未来の予定を優先する
    static func todayAlarms() -> [WidgetAlarmEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = start.addingTimeInterval(86400)
        let now = Date()
        let all = loadAll()

        // スケジュール済み：未来かつ今日中（fireDate 昇順）
        let scheduled = all
            .filter { $0.completionStatus == nil && $0.fireDate > now && $0.fireDate < end }
            .sorted { $0.fireDate < $1.fireDate }

        // 反応待ち：今日中（過去時刻でも表示、fireDate 昇順）
        let awaiting = all
            .filter { $0.completionStatus == .awaitingResponse && $0.fireDate >= start && $0.fireDate < end }
            .sorted { $0.fireDate < $1.fireDate }

        return scheduled + awaiting
    }

    /// 今日の全アラームを返す（完了済みを含む）- Large ウィジェット用
    static func todayAlarmsAll() -> [WidgetAlarmEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end   = start.addingTimeInterval(86400)
        return loadAll()
            .filter { $0.fireDate >= start && $0.fireDate < end }
            .sorted { $0.fireDate < $1.fireDate }
    }
}

// MARK: - 日付フォーマット（Widget内のユーティリティ）

extension Date {
    /// HH:mm 形式
    var widgetTimeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    /// 「今日 / 明日 / M月d日」
    var widgetDateLabel: String {
        if Calendar.current.isDateInToday(self)    { return "今日" }
        if Calendar.current.isDateInTomorrow(self) { return "明日" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f.string(from: self)
    }

    /// 残り時間を「あとX日」「あとX時間Y分」などに変換
    var remainingString: String {
        let diff = Int(timeIntervalSinceNow)
        guard diff > 0 else { return "まもなく" }
        let h = diff / 3600
        let m = (diff % 3600) / 60
        if h >= 24 { return "あと\(h / 24)日" }
        if h > 0 { return "あと\(h)時間\(m)分" }
        if m > 0 { return "あと\(m)分" }
        return "まもなく"
    }
}
