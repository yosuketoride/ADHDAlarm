import Foundation

/// このセッション中に一度表示した alerting アラームIDを管理する
/// 「ユーザーが処理済み」を表す HandledAlarmStore とは分離し、
/// アプリ復帰時の二重表示だけを防ぐ
@MainActor
final class PresentedAlarmStore {
    static let shared = PresentedAlarmStore()

    private var presentedIDs: Set<String> = []

    private init() {}

    func markPresented(_ alarmKitID: UUID) {
        presentedIDs.insert(alarmKitID.uuidString)
    }

    func isPresented(_ alarmKitID: UUID) -> Bool {
        presentedIDs.contains(alarmKitID.uuidString)
    }

    /// 現在 alerting 中のIDだけを残す
    func retainOnly(_ alarmKitIDs: Set<UUID>) {
        let activeIDs = Set(alarmKitIDs.map(\.uuidString))
        presentedIDs = presentedIDs.intersection(activeIDs)
    }

    func clearAll() {
        presentedIDs.removeAll()
    }
}
