import Foundation

/// App GroupのJSONからAlarmEventを読み込むWidget専用ヘルパー
enum WidgetDataProvider {

    private static let appGroupID = "group.com.yosuke.WasurenboAlarm"
    private static let fileName   = "alarm_events.json"

    /// App Groupコンテナからアラーム一覧を取得する
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

    /// 今日の未来アラームをすべて返す（早い順）- Medium ウィジェット用
    static func todayAlarms() -> [WidgetAlarmEvent] {
        let end = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        return loadAll()
            .filter { $0.completionStatus == nil && $0.fireDate > Date() && $0.fireDate < end }
            .sorted { $0.fireDate < $1.fireDate }
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

    /// 残り時間を「あと X時間Y分」などに変換
    var remainingString: String {
        let diff = Int(timeIntervalSinceNow)
        guard diff > 0 else { return "まもなく" }
        let h = diff / 3600
        let m = (diff % 3600) / 60
        if h > 0 { return "あと\(h)時間\(m)分" }
        if m > 0 { return "あと\(m)分" }
        return "まもなく"
    }
}
