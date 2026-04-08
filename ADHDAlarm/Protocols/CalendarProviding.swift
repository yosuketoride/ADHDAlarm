import Foundation

/// カレンダーデータの取得・書き込みを抽象化するプロトコル
/// V2でGoogleカレンダー等に差し替える際はこのプロトコルに準拠した実装を作るだけでよい
protocol CalendarProviding {
    /// アプリが作成した予定のみを取得する（マーカーで識別）
    func fetchAppEvents() async throws -> [AlarmEvent]

    /// 指定期間のアプリ作成予定を取得する
    func fetchAppEvents(from: Date, to: Date) async throws -> [AlarmEvent]

    /// アプリ作成予定を alarmID（notes内マーカー）で再探索する
    func findAppEvent(id: UUID) async throws -> AlarmEvent?

    /// EventKitに予定を書き込む。calendarIDがnilの場合はデフォルトカレンダーに保存（無料版）
    @discardableResult
    func writeEvent(_ alarm: AlarmEvent, to calendarID: String?) async throws -> String

    /// EventKitから予定を削除する
    func deleteEvent(eventKitIdentifier: String) async throws

    /// 利用可能なカレンダー一覧を取得する（PRO版のカレンダー選択に使用）
    func availableCalendars() async throws -> [CalendarInfo]

    /// 外部カレンダーの取り込み候補を取得する（PRO機能：手動インポート用）
    /// - 書き込み可能カレンダーのみ（祝日等の読み取り専用を自動除外）
    /// - 今後の予定のみ（過去は除外）
    /// - 非終日・非繰り返し・未取り込み済みのみ
    /// - calendarIdentifiers が nil の場合は全書き込み可能カレンダーを対象にする
    func fetchImportCandidates(
        from: Date,
        to: Date,
        excludingEKIdentifiers: Set<String>,
        calendarIdentifiers: Set<String>?
    ) async throws -> [ImportCandidate]

    /// 既存EKEventのnotesにマーカーを追記する（上書きしない・冪等）
    /// - イベントが見つからない場合は CalendarImportError.eventNotFound を throw する
    func appendMarker(to ekIdentifier: String, alarmID: UUID) async throws
}

/// カレンダー取り込み時のエラー
enum CalendarImportError: Error {
    case eventNotFound
}

/// カレンダー情報の軽量表現
struct CalendarInfo: Identifiable, Hashable {
    let id: String          // EKCalendar.calendarIdentifier
    let title: String
    let colorHex: String?
}
