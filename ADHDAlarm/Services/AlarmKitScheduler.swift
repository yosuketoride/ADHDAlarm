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
        let schedule = Alarm.Schedule.fixed(actualFireDate)

        // AlarmKitにはシステムデフォルトの「ピピピピ」音を使わせる
        // 音声ナレーション（.caf）はアプリ側の RingingViewModel が排他的に担当する
        // ※ .named(fileName) を渡すとAlarmKitがOS側でナレーションを再生してしまい、
        //   アラームのみモードでも音声が流れるバグの原因となるため使用しない
        let config = AlarmManager.AlarmConfiguration<AlarmMetadataInfo>.alarm(
            schedule: schedule,
            attributes: attrs
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
