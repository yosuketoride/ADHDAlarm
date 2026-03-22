import Foundation

/// カレンダーデータの取得・書き込みを抽象化するプロトコル
/// V2でGoogleカレンダー等に差し替える際はこのプロトコルに準拠した実装を作るだけでよい
protocol CalendarProviding {
    /// アプリが作成した予定のみを取得する（マーカーで識別）
    func fetchAppEvents() async throws -> [AlarmEvent]

    /// 指定期間のアプリ作成予定を取得する
    func fetchAppEvents(from: Date, to: Date) async throws -> [AlarmEvent]

    /// EventKitに予定を書き込む。calendarIDがnilの場合はデフォルトカレンダーに保存（無料版）
    @discardableResult
    func writeEvent(_ alarm: AlarmEvent, to calendarID: String?) async throws -> String

    /// EventKitから予定を削除する
    func deleteEvent(eventKitIdentifier: String) async throws

    /// 利用可能なカレンダー一覧を取得する（PRO版のカレンダー選択に使用）
    func availableCalendars() async throws -> [CalendarInfo]
}

/// カレンダー情報の軽量表現
struct CalendarInfo: Identifiable, Hashable {
    let id: String          // EKCalendar.calendarIdentifier
    let title: String
    let colorHex: String?
}
