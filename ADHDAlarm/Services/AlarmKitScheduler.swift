import Foundation
import SwiftUI
import AlarmKit
import ActivityKit

/// AlarmKitを使ったAlarmScheduling実装
/// iOS 26 AlarmManager でマナーモードを貫通するアラームをスケジュールする
final class AlarmKitScheduler: AlarmScheduling {

    private let alarmManager = AlarmManager.shared

    // MARK: - AlarmScheduling

    /// アラームをスケジュールする
    /// - Returns: AlarmKitに登録したアラームのID
    @discardableResult
    func schedule(_ alarm: AlarmEvent) async throws -> UUID {
        let alarmID = alarm.alarmKitIdentifier ?? UUID()

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
        return alarmID
    }

    /// アラームをキャンセルする
    func cancel(alarmKitID: UUID) async throws {
        try await alarmManager.cancel(id: alarmKitID)  // AlarmKit APIはasync
    }

    /// 複数のアラームを一括キャンセル
    func cancelAll(alarmKitIDs: [UUID]) async throws {
        for id in alarmKitIDs {
            try await alarmManager.cancel(id: id)  // AlarmKit APIはasync
        }
    }

    /// スケジュール済みのアラームID一覧
    /// AlarmKit公式にlistAll()がないためローカルマッピングで管理する
    /// Phase 3のSyncEngine実装時に AlarmManager.shared のプロパティを再調査する
    func scheduledIDs() async -> [UUID] {
        []
    }
}

// MARK: - AlarmMetadataInfo

/// AlarmKitのメタデータ型。CustomStringConvertibleでOptional括りを防ぐ
struct AlarmMetadataInfo: AlarmMetadata, CustomStringConvertible {
    let title: String

    var description: String { title }
}
