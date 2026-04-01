import Foundation

/// 日本語テキストから予定タイトルと日時を抽出するNLParsing実装
/// V1スコープ: 単発予定のみ（繰り返しなし）、日本語のみ
final class NLParserService: NLParsing {

    /// 予定タイトルから絵文字を推定する
    func inferEmoji(from title: String) -> String? {
        let mappings: [(keywords: [String], emoji: String)] = [
            (["薬", "服薬", "飲む", "錠"], "💊"),
            (["病院", "診察", "クリニック", "医者"], "🏥"),
            (["ご飯", "食事", "昼", "朝", "夜", "夕"], "🍴"),
            (["運動", "散歩", "ウォーキング", "体操"], "🚶"),
            (["電話", "連絡", "コール"], "📞"),
            (["美容院", "カット", "髪"], "💇"),
            (["買い物", "スーパー", "コンビニ"], "🛒"),
            (["ゴミ", "ごみ", "資源"], "🗑️"),
            (["掃除", "片付け"], "🧹"),
            (["寝る", "就寝", "お昼寝"], "😴"),
        ]

        let normalized = title.lowercased()
        for (keywords, emoji) in mappings {
            if keywords.contains(where: { normalized.contains($0.lowercased()) }) {
                return emoji
            }
        }
        return nil
    }

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

        // 1. 繰り返しルールを抽出する（繰り返し語句を消費してタイトルから除去）
        let (recurrenceRule, recurrenceConsumed) = extractRecurrence(from: workText)
        var textAfterRecurrence = workText
        if let range = recurrenceConsumed {
            textAfterRecurrence.removeSubrange(range)
            textAfterRecurrence = textAfterRecurrence.trimmingCharacters(in: .whitespaces)
        }

        // 2. 日時を抽出する
        guard let (fireDate, consumedRanges, hasExplicitDate) = extractDateTime(from: textAfterRecurrence) else {
            // 繰り返し予定で時刻だけ指定の場合も失敗扱い（日時必須）
            return nil
        }

        // 3. 日時に使った部分を除去してタイトルを取り出す
        var title = textAfterRecurrence
        for range in consumedRanges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            title.removeSubrange(range)
        }
        title = stripFillers(title)
        guard !title.isEmpty else { return nil }

        return ParsedInput(title: title, fireDate: fireDate, recurrenceRule: recurrenceRule, hasExplicitDate: hasExplicitDate)
    }

    // MARK: - 繰り返しパターン抽出

    /// テキストから繰り返しルールを検出する
    /// - Returns: (RecurrenceRule?, 消費した範囲)
    private func extractRecurrence(from text: String) -> (RecurrenceRule?, Range<String.Index>?) {
        // 「毎月X日」
        if let match = text.range(of: #"毎月(\d{1,2})日"#, options: .regularExpression) {
            let s = String(text[match])
            if let m = s.firstMatch(of: /毎月(\d{1,2})日/), let day = Int(m.output.1) {
                return (.monthly(day: day), match)
            }
        }

        // 「毎週X曜」（複数曜日対応: 「毎週月曜と水曜」「毎週月・水」）
        let weekdayMap: [(String, Int)] = [
            ("月曜", 2), ("火曜", 3), ("水曜", 4), ("木曜", 5), ("金曜", 6), ("土曜", 7), ("日曜", 1)
        ]
        if text.contains("毎週") {
            var weekdays: [Int] = []
            for (name, num) in weekdayMap {
                if text.contains(name) { weekdays.append(num) }
            }
            if !weekdays.isEmpty {
                // 「毎週〜曜」を消費する範囲（毎週から最後の曜日語句まで）
                if let range = text.range(of: "毎週") {
                    return (.weekly(weekdays: weekdays.sorted()), range)
                }
            }
        }

        // 「毎日」「毎朝」「毎晩」「毎夜」
        let dailyKeywords = ["毎日", "毎朝", "毎晩", "毎夜", "毎夕"]
        for keyword in dailyKeywords {
            if let range = text.range(of: keyword) {
                return (.daily, range)
            }
        }

        return (nil, nil)
    }

    // MARK: - 日時抽出

    /// - Returns: (日時, 消費範囲リスト, 日付を明示的に検出したか)
    private func extractDateTime(from text: String) -> (Date, [Range<String.Index>], Bool)? {
        let calendar = Calendar.current
        let now = Date()
        var consumed: [Range<String.Index>] = []

        // ① 「X分後」「X時間後」（相対時刻）→ 日付明示扱い
        if let (minutes, range) = matchRelativeMinutes(text) {
            let date = now.addingTimeInterval(TimeInterval(minutes * 60))
            return (date, [range], true)
        }

        // ② 「X時間後」→ 日付明示扱い
        if let (hours, range) = matchRelativeHours(text) {
            let date = now.addingTimeInterval(TimeInterval(hours * 3600))
            return (date, [range], true)
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
        // 日付を明示的に指定した（dateConsumedがnilでない）場合のみtrue
        return (baseDate, consumed, dateConsumed != nil)
    }

    // MARK: - 個別パターンマッチ

    /// 「30分後」「15分後」→ 分数を返す
    /// レビュー指摘 #4: range(of:)+firstMatch の二重パースを Swift Regex 1回に統一
    private func matchRelativeMinutes(_ text: String) -> (Int, Range<String.Index>)? {
        guard let m = text.firstMatch(of: /(\d+)\s*分後/),
              let minutes = Int(m.output.1) else { return nil }
        return (minutes, m.range)
    }

    /// 「2時間後」「1時間後」→ 時間数を返す
    /// レビュー指摘 #4: range(of:)+firstMatch の二重パースを Swift Regex 1回に統一
    private func matchRelativeHours(_ text: String) -> (Int, Range<String.Index>)? {
        guard let m = text.firstMatch(of: /(\d+)\s*時間後/),
              let hours = Int(m.output.1) else { return nil }
        return (hours, m.range)
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
        // レビュー指摘 #3: ハードコード2026を除去。現在の年から動的に計算する。
        if let date = calendar.date(from: components), date < Date() {
            let currentYear = Calendar.current.component(.year, from: Date())
            components.year = currentYear + 1
        }
        let date = calendar.date(from: components) ?? Date()
        return (date, match)
    }

    /// 「15時」「8時30分」「午後3時」→ (hour, minute) を返す
    private func matchTime(_ text: String) -> (Int, Int, Range<String.Index>)? {
        // 「午後X時」「午後X時Y分」（分なしも正しく15時扱いにするため分パート全体をオプショナルに）
        if let match = text.range(of: #"午後(\d{1,2})時(\d{1,2}分)?"#, options: .regularExpression) {
            let s = String(text[match])
            if let m = s.firstMatch(of: /午後(\d{1,2})時(\d{1,2})?分?/),
               let h = Int(m.output.1) {
                let hour = h < 12 ? h + 12 : h
                let min  = m.output.2.flatMap { Int($0) } ?? 0
                return (hour, min, match)
            }
        }
        // 「午前X時」「午前X時Y分」
        if let match = text.range(of: #"午前(\d{1,2})時(\d{1,2}分)?"#, options: .regularExpression) {
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
