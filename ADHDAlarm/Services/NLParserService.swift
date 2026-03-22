import Foundation

/// 日本語テキストから予定タイトルと日時を抽出するNLParsing実装
/// V1スコープ: 単発予定のみ（繰り返しなし）、日本語のみ
final class NLParserService: NLParsing {

    /// 日時だけを抽出する（タイトルが無くても成功する）
    /// Siri の2ステップ対話で "dateText" だけを渡す場合に使う
    func parseDate(text: String) -> Date? {
        let workText = text.trimmingCharacters(in: .whitespaces)
        guard !workText.isEmpty else { return nil }
        return extractDateTime(from: workText)?.0
    }

    func parse(text: String) -> ParsedInput? {
        let workText = text.trimmingCharacters(in: .whitespaces)
        guard !workText.isEmpty else { return nil }

        // 1. 日時を抽出する
        guard let (fireDate, consumedRanges) = extractDateTime(from: workText) else {
            return nil
        }

        // 2. 日時に使った部分を除去してタイトルを取り出す
        var title = workText
        for range in consumedRanges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            title.removeSubrange(range)
        }
        title = stripFillers(title)
        guard !title.isEmpty else { return nil }

        return ParsedInput(title: title, fireDate: fireDate)
    }

    // MARK: - 日時抽出

    private func extractDateTime(from text: String) -> (Date, [Range<String.Index>])? {
        let calendar = Calendar.current
        let now = Date()
        var consumed: [Range<String.Index>] = []

        // ① 「X分後」「X時間後」（相対時刻）
        if let (minutes, range) = matchRelativeMinutes(text) {
            let date = now.addingTimeInterval(TimeInterval(minutes * 60))
            return (date, [range])
        }

        // ② 「X時間後」
        if let (hours, range) = matchRelativeHours(text) {
            let date = now.addingTimeInterval(TimeInterval(hours * 3600))
            return (date, [range])
        }

        // ③ 日付部分と時刻部分を個別に抽出して組み合わせる
        var baseDate: Date = now
        var dateConsumed: Range<String.Index>? = nil
        var timeConsumed: Range<String.Index>? = nil

        // 日付パターンを探す（月日 / 曜日 / 今日・明日・明後日・来週）
        if let (d, r) = matchAbsoluteDate(text) {
            baseDate = d
            dateConsumed = r
        } else if let (d, r) = matchRelativeDate(text) {
            baseDate = d
            dateConsumed = r
        }
        // 日付の指定がなければ「今日」をベースに

        // 時刻パターンを探す
        if let (h, m, r) = matchTime(text) {
            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            components.hour   = h
            components.minute = m
            components.second = 0
            if let date = calendar.date(from: components) {
                // 時刻が過去で日付指定なし → 翌日と解釈
                if date < now && dateConsumed == nil {
                    baseDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
                } else {
                    baseDate = date
                }
                timeConsumed = r
            }
        } else if dateConsumed != nil {
            // 日付はあるが時刻なし → その日の朝9時をデフォルトに
            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            components.hour   = 9
            components.minute = 0
            components.second = 0
            baseDate = calendar.date(from: components) ?? baseDate
        } else {
            // 日付も時刻も抽出できなかった
            return nil
        }

        if let dr = dateConsumed { consumed.append(dr) }
        if let tr = timeConsumed { consumed.append(tr) }
        return (baseDate, consumed)
    }

    // MARK: - 個別パターンマッチ

    /// 「30分後」「15分後」→ 分数を返す
    private func matchRelativeMinutes(_ text: String) -> (Int, Range<String.Index>)? {
        let pattern = #"(\d+)\s*分後"#
        guard let match = text.range(of: pattern, options: .regularExpression),
              let numStr = text[match].firstMatch(of: /(\d+)/)?.output.1,
              let minutes = Int(numStr) else { return nil }
        return (minutes, match)
    }

    /// 「2時間後」「1時間後」→ 時間数を返す
    private func matchRelativeHours(_ text: String) -> (Int, Range<String.Index>)? {
        let pattern = #"(\d+)\s*時間後"#
        guard let match = text.range(of: pattern, options: .regularExpression),
              let numStr = text[match].firstMatch(of: /(\d+)/)?.output.1,
              let hours = Int(numStr) else { return nil }
        return (hours, match)
    }

    /// 「今日」「明日」「明後日」「来週の月曜」などを Date に変換
    private func matchRelativeDate(_ text: String) -> (Date, Range<String.Index>)? {
        let calendar = Calendar.current
        let now = Date()

        let patterns: [(String, Date?)] = [
            ("明後日",  calendar.date(byAdding: .day, value: 2, to: now)),
            ("あさって", calendar.date(byAdding: .day, value: 2, to: now)),
            ("明日",    calendar.date(byAdding: .day, value: 1, to: now)),
            ("今日",    now),
            ("来週",    calendar.date(byAdding: .weekOfYear, value: 1, to: now)),
        ]

        for (keyword, date) in patterns {
            if let range = text.range(of: keyword), let date {
                return (startOfDay(date), range)
            }
        }

        // 「来週の月曜」など曜日パターン
        let weekdayMap: [String: Int] = [
            "月曜": 2, "火曜": 3, "水曜": 4, "木曜": 5, "金曜": 6, "土曜": 7, "日曜": 1
        ]
        for (name, weekday) in weekdayMap {
            if let range = text.range(of: name) {
                let date = nextWeekday(weekday, from: now)
                return (startOfDay(date), range)
            }
        }
        return nil
    }

    /// 「3月20日」「10月5日」→ Date に変換
    private func matchAbsoluteDate(_ text: String) -> (Date, Range<String.Index>)? {
        let pattern = #"(\d{1,2})月(\d{1,2})日"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        let matchStr = String(text[match])
        guard let mMatch = matchStr.firstMatch(of: /(\d{1,2})月(\d{1,2})日/),
              let month = Int(mMatch.output.1),
              let day   = Int(mMatch.output.2) else { return nil }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: Date())
        components.month = month
        components.day   = day
        components.hour  = 9
        components.minute = 0
        components.second = 0

        // 過去になる場合は翌年に設定
        if let date = calendar.date(from: components), date < Date() {
            components.year = (components.year ?? 2026) + 1
        }
        let date = calendar.date(from: components) ?? Date()
        return (date, match)
    }

    /// 「15時」「8時30分」「午後3時」→ (hour, minute) を返す
    private func matchTime(_ text: String) -> (Int, Int, Range<String.Index>)? {
        // 「午後X時」
        if let match = text.range(of: #"午後(\d{1,2})時(\d{1,2})分?"#, options: .regularExpression) {
            let s = String(text[match])
            if let m = s.firstMatch(of: /午後(\d{1,2})時(\d{1,2})?分?/),
               let h = Int(m.output.1) {
                let hour = h < 12 ? h + 12 : h
                let min  = m.output.2.flatMap { Int($0) } ?? 0
                return (hour, min, match)
            }
        }
        // 「午前X時」
        if let match = text.range(of: #"午前(\d{1,2})時(\d{1,2})分?"#, options: .regularExpression) {
            let s = String(text[match])
            if let m = s.firstMatch(of: /午前(\d{1,2})時(\d{1,2})?分?/),
               let h = Int(m.output.1) {
                let min = m.output.2.flatMap { Int($0) } ?? 0
                return (h, min, match)
            }
        }
        // 「15時30分」「8時」
        if let match = text.range(of: #"(\d{1,2})時(\d{1,2})分"#, options: .regularExpression) {
            let s = String(text[match])
            if let m = s.firstMatch(of: /(\d{1,2})時(\d{1,2})分/),
               let h = Int(m.output.1), let min = Int(m.output.2) {
                return (h, min, match)
            }
        }
        if let match = text.range(of: #"(\d{1,2})時"#, options: .regularExpression) {
            let s = String(text[match])
            if let m = s.firstMatch(of: /(\d{1,2})時/), let h = Int(m.output.1) {
                return (h, 0, match)
            }
        }
        // 「15:30」「8:00」
        if let match = text.range(of: #"(\d{1,2}):(\d{2})"#, options: .regularExpression) {
            let s = String(text[match])
            if let m = s.firstMatch(of: /(\d{1,2}):(\d{2})/),
               let h = Int(m.output.1), let min = Int(m.output.2) {
                return (h, min, match)
            }
        }
        return nil
    }

    // MARK: - フィラー除去

    /// 予定タイトルに不要な語句を除去する
    private func stripFillers(_ text: String) -> String {
        let fillers = [
            "起こして", "おこして", "アラームをセットして", "アラームを", "アラーム",
            "お願いします", "お願い", "にセットして", "をセット", "セットして",
            "に", "の", "で", "を", "は", "が", "と", "へ",
        ]
        var result = text
        for filler in fillers {
            result = result.replacingOccurrences(of: filler, with: "")
        }
        // 連続する空白を1つにまとめる
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 日付ユーティリティ

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func nextWeekday(_ weekday: Int, from date: Date) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = weekday
        return calendar.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTime
        ) ?? date
    }
}
