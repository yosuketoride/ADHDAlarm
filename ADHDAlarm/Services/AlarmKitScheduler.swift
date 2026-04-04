import Foundation
import SwiftUI
import AlarmKit
import ActivityKit
import UserNotifications

/// AlarmKitを使ったAlarmScheduling実装
/// iOS 26 AlarmManager でマナーモードを貫通するアラームをスケジュールする
final class AlarmKitScheduler: AlarmScheduling {

    private let alarmManager = AlarmManager.shared

    nonisolated init() {}

    // MARK: - AlarmScheduling

    /// アラームをスケジュールする
    /// - Returns: AlarmKitに登録したアラームのID
    @discardableResult
    func schedule(_ alarm: AlarmEvent) async throws -> UUID {
        let alarmID = alarm.alarmKitIdentifier ?? UUID()
        await HandledAlarmStore.shared.clearHandled(alarmID)

        // AlarmPresentation.Alert は title のみ（body引数は存在しない）
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.title)
        )
        let presentation = AlarmPresentation(alert: alert)

        // AlarmAttributesはジェネリック。メタデータ型を明示的に指定する
        let attrs = AlarmAttributes<AlarmMetadataInfo>(
            presentation: presentation,
            tintColor: .blue
        )

        // preNotificationMinutes分前にスケジュール（0分の場合はジャストタイム）
        let actualFireDate = alarm.fireDate.addingTimeInterval(-Double(alarm.preNotificationMinutes * 60))
        // レビュー指摘 #4: 計算結果が過去日時になった場合（ギリギリ登録 + 大きな事前通知時間など）
        // AlarmKit に過去日時を渡すとエラー/クラッシュのリスクがあるため、最低5秒後を保証する
        let safeFireDate = max(actualFireDate, Date().addingTimeInterval(5))
        let schedule = Alarm.Schedule.fixed(safeFireDate)

        // 音声ファイルがある場合はAlarmKitに渡す（バックグラウンド・ロック画面でも声が鳴る）
        // .named(fileName) は Library/Sounds/ 直下のファイルを参照する
        // アラームのみモードの場合、呼び出し側が alarm.voiceFileName = nil にしてから渡すこと
        let sound: ActivityKit.AlertConfiguration.AlertSound = alarm.voiceFileName.map { .named($0) } ?? .default
        let config = AlarmManager.AlarmConfiguration<AlarmMetadataInfo>.alarm(
            schedule: schedule,
            attributes: attrs,
            sound: sound
        )

        _ = try await alarmManager.schedule(id: alarmID, configuration: config)

        // AlarmKit が発行する通知には categoryIdentifier を付与できないため、
        // 同じ発火時刻にカテゴリ付きのローカル通知を別途スケジュールする。
        // これによりバナーに「止める / あとで / 今日は休む」ボタンが表示される。
        await scheduleActionableNotification(for: alarm, alarmID: alarmID, fireDate: safeFireDate)

        return alarmID
    }

    /// アクションボタン付きローカル通知を AlarmKit と同じ発火時刻で登録する
    private func scheduleActionableNotification(
        for alarm: AlarmEvent,
        alarmID: UUID,
        fireDate: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.title
        content.body = alarm.preNotificationMinutes == 0
            ? "時間になりました"
            : "あと\(alarm.preNotificationMinutes)分です"
        content.sound = .default
        content.categoryIdentifier = Constants.Notification.alarmCategoryID
        // アクション処理側でアラームを特定するためにAlarmKit IDを埋め込む
        content.userInfo = [ForegroundNotificationDelegate.alarmKitIDKey: alarmID.uuidString]

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(
            identifier: "alarm-action-\(alarmID.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// アラームをキャンセルする
    func cancel(alarmKitID: UUID) async throws {
        try alarmManager.cancel(id: alarmKitID)
        // 対応するアクション付きローカル通知も削除する
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["alarm-action-\(alarmKitID.uuidString)"]
        )
    }

    /// 複数のアラームを一括キャンセル
    func cancelAll(alarmKitIDs: [UUID]) async throws {
        for id in alarmKitIDs {
            try alarmManager.cancel(id: id)
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["alarm-action-\(id.uuidString)"]
            )
        }
    }

    /// スケジュール済みのアラームID一覧
    /// AlarmKit公式にlistAll()がないためローカルマッピングで管理する
    ///
    /// ⚠️ レビュー指摘: 空配列を返すスタブのままだと SyncEngine が
    /// 「AlarmKitに何も登録されていない」と誤認し、登録済みアラームを再登録し続けるバグになる。
    /// AlarmEventStore.shared.loadAll() から alarmKitIdentifiers を集めて返すことで代替する。
    /// Phase 3 で AlarmManager.shared の公式プロパティが確認できたら置き換えること。
    func scheduledIDs() async -> [UUID] {
        let allEvents = AlarmEventStore.shared.loadAll()
        let ids = allEvents.flatMap { event -> [UUID] in
            if !event.alarmKitIdentifiers.isEmpty {
                return event.alarmKitIdentifiers
            }
            return [event.alarmKitIdentifier].compactMap { $0 }
        }
        return Array(Set(ids))
    }
}

// MARK: - AlarmMetadataInfo

/// AlarmKitのメタデータ型。CustomStringConvertibleでOptional括りを防ぐ
struct AlarmMetadataInfo: AlarmMetadata, CustomStringConvertible {
    let title: String

    var description: String { title }
}
