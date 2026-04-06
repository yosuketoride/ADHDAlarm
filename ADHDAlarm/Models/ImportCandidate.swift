import Foundation

/// カレンダーから取り込み可能な予定の軽量DTO
/// EKEventを直接ViewModelに渡さないためのラッパー
struct ImportCandidate: Identifiable {
    /// EKEvent.eventIdentifier（一意キー）
    let id: String
    let title: String
    let startDate: Date
    let calendarName: String
    /// EKCalendar.calendarIdentifier（カレンダーが取得できない場合はnil）
    let calendarIdentifier: String?
}
