import Foundation
import WidgetKit
import Observation

/// ダッシュボードの状態管理
@Observable
final class DashboardViewModel {

    // MARK: - 状態

    var events: [AlarmEvent] = []
    var isWidgetInstalled = false
    var isLoading = false

    /// 削除待ちアラーム（3秒以内にUndoで復活可能）
    var pendingDelete: AlarmEvent?
    private var deleteTimer: Timer?

    var nextAlarm: AlarmEvent? {
        events.filter { $0.fireDate > Date() }.min(by: { $0.fireDate < $1.fireDate })
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "おはようございます。"
        case 11..<18: return "こんにちは。"
        default:      return "こんばんは。"
        }
    }

    var eventSummary: String {
        let upcoming = events.filter { $0.fireDate > Date() }
        if upcoming.isEmpty {
            return "今日のご予定はまだありません。"
        }
        return "今日は\(upcoming.count)件のご予定があります。"
    }

    // MARK: - 依存

    private let calendarProvider: CalendarProviding
    private let eventStore: AlarmEventStore

    init(
        calendarProvider: CalendarProviding = AppleCalendarProvider(),
        eventStore: AlarmEventStore = .shared
    ) {
        self.calendarProvider = calendarProvider
        self.eventStore = eventStore
    }

    // MARK: - データ取得

    /// アプリ作成の予定をロードする
    func loadEvents() async {
        isLoading = true
        // ローカルストアから即時表示（EventKitの非同期待ち不要）
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        events = eventStore.loadAll()
            .filter { $0.fireDate >= startOfToday && $0.fireDate < startOfTomorrow }
            .sorted { $0.fireDate < $1.fireDate }
        isLoading = false
    }

    /// ウィジェットの設置状態を確認する
    func checkWidgetStatus() async {
        let configs = try? await WidgetCenter.shared.currentConfigurations()
        isWidgetInstalled = !(configs?.isEmpty ?? true)
    }

    /// 予定を削除する（3秒間はUndoで復活可能なソフト削除）
    func deleteEvent(_ alarm: AlarmEvent) async {
        // 既存の削除待ちがあれば即座に確定させてから新規削除を受け付ける
        if let pending = pendingDelete {
            await commitDelete(pending)
        }
        deleteTimer?.invalidate()

        // 画面からは即座に除去（Undoで復活するまでは見えない）
        events.removeAll { $0.id == alarm.id }
        pendingDelete = alarm

        // 3秒後に実際の削除処理を実行
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self, let pending = self.pendingDelete, pending.id == alarm.id else { return }
            Task { await self.commitDelete(pending) }
        }
    }

    /// 削除をキャンセルしてアラームをリストに復活させる
    func undoDelete() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        if let alarm = pendingDelete {
            events.append(alarm)
            events.sort { $0.fireDate < $1.fireDate }
        }
        pendingDelete = nil
    }

    /// 実際の削除処理（EventKit + AlarmKit + ローカル）
    private func commitDelete(_ alarm: AlarmEvent) async {
        if alarm.id == pendingDelete?.id {
            pendingDelete = nil
        }
        // EventKit から削除
        if let ekID = alarm.eventKitIdentifier {
            try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
        }
        // AlarmKit からキャンセル（複数登録対応）
        let idsToCancel = alarm.alarmKitIdentifiers.isEmpty
            ? [alarm.alarmKitIdentifier].compactMap { $0 }
            : alarm.alarmKitIdentifiers
        if !idsToCancel.isEmpty {
            try? await AlarmKitScheduler().cancelAll(alarmKitIDs: idsToCancel)
        }
        // 音声ファイル削除
        VoiceFileGenerator().deleteAudio(alarmID: alarm.id)
        // ローカルから削除
        eventStore.delete(id: alarm.id)
        // WidgetKitを更新
        WidgetCenter.shared.reloadAllTimelines()
    }
}
