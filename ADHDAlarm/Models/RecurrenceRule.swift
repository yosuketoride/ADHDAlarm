import Foundation

/// 繰り返しルール
///
/// AlarmKitは繰り返しをネイティブサポートしないため、
/// 実装側で次のN件を個別スケジューリングする。
enum RecurrenceRule: Codable, Equatable, Hashable {
    /// 毎日（時刻のみ固定）
    case daily
    /// 毎週（曜日指定。1=日曜〜7=土曜）
    case weekly(weekdays: [Int])
    /// 毎月X日
    case monthly(day: Int)

    // MARK: - 表示名

    var displayName: String {
        switch self {
        case .daily:
            return "毎日繰り返し"
        case .weekly(let weekdays):
            let sorted = weekdays.sorted()
            let names = sorted.map { Self.weekdayName($0) }.joined(separator: "・")
            return "毎週\(names)繰り返し"
        case .monthly(let day):
            return "毎月\(day)日繰り返し"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .daily:
            return "毎日"
        case .weekly(let weekdays):
            let sorted = weekdays.sorted()
            let names = sorted.map { Self.weekdayName($0) }.joined(separator: "・")
            return "毎週\(names)"
        case .monthly(let day):
            return "毎月\(day)日"
        }
    }

    // MARK: - 次のN件の発火日時を計算

    /// 指定日時以降の次のN件の発火日時を返す
    func nextOccurrences(from startDate: Date, count: Int) -> [Date] {
        let calendar = Calendar.current
        var result: [Date] = []
        var current = startDate

        while result.count < count {
            switch self {
            case .daily:
                result.append(current)
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current

            case .weekly(let weekdays):
                let weekday = calendar.component(.weekday, from: current)
                if weekdays.contains(weekday) {
                    result.append(current)
                }
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current

            case .monthly(let day):
                let currentDay = calendar.component(.day, from: current)
                if currentDay == day {
                    result.append(current)
                }
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            }
        }
        return result
    }

    /// 事前スケジューリングする件数（dailyは7件、weeklyは4件、monthlyは3件）
    var scheduledCount: Int {
        switch self {
        case .daily:   return 7
        case .weekly:  return 4
        case .monthly: return 3
        }
    }

    // MARK: - Private

    private static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "日"
        case 2: return "月"
        case 3: return "火"
        case 4: return "水"
        case 5: return "木"
        case 6: return "金"
        case 7: return "土"
        default: return ""
        }
    }
}
