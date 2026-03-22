import Foundation

/// AlarmKitのスケジューリングを抽象化するプロトコル
protocol AlarmScheduling {
    /// アラームをスケジュールする。スケジュール済みのAlarmKit IDを返す
    @discardableResult
    func schedule(_ alarm: AlarmEvent) async throws -> UUID

    /// アラームをキャンセルする
    func cancel(alarmKitID: UUID) async throws

    /// 複数のアラームを一括キャンセル
    func cancelAll(alarmKitIDs: [UUID]) async throws

    /// 現在スケジュール済みのアラームID一覧を返す
    /// ※ AlarmKit APIにlistAll()が存在しない場合はローカルマッピングから返す
    func scheduledIDs() async -> [UUID]
}
