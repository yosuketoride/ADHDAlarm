import Foundation

extension Date {
    /// 日本語の日付表示（例: 3月20日（木））
    var japaneseDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: self)
    }

    /// 省スペース用の日付表示（例: 3月20日）
    var japaneseCompactDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: self)
    }

    /// 日本語の時刻表示（例: 15:00）
    var japaneseTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    /// 「明日の15時」などの自然な日本語表現
    var naturalJapaneseString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "今日の\(japaneseTimeString)"
        } else if calendar.isDateInTomorrow(self) {
            return "明日の\(japaneseTimeString)"
        } else {
            return "\(japaneseDateString) \(japaneseTimeString)"
        }
    }
}
