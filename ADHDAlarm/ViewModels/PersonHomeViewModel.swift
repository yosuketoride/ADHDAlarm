import Foundation
import Observation
import UIKit
import WidgetKit

// MARK: - ふくろうの状態

enum OwlState {
    case normal
    case happy
    case worried
    case sleepy
    case sunglasses

    /// 画像アセット名に使うキー（owl_stageN_{assetKey}）
    var assetKey: String {
        switch self {
        case .normal:     return "normal"
        case .happy:      return "happy"
        case .worried:    return "worried"
        case .sleepy:     return "sleepy"
        case .sunglasses: return "sunglasses"
        }
    }
}

// MARK: - 時間帯

private enum TimeSlot {
    case morning    // 5〜10時
    case afternoon  // 11〜16時
    case evening    // 17〜20時
    case night      // 21〜4時

    static var current: TimeSlot {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<11:  return .morning
        case 11..<17: return .afternoon
        case 17..<21: return .evening
        default:      return .night
        }
    }
}

// MARK: - PersonHomeViewModel

/// 当事者ホーム画面の状態管理
/// DashboardViewModel のロジックを移行し、フクロウ連動・折りたたみを追加
@Observable @MainActor
final class PersonHomeViewModel {

    // MARK: - 予定データ
    var events: [AlarmEvent] = []          // 今日の予定（ソート済み）
    var upcomingEvents: [AlarmEvent] = []  // 明日以降（最大2件表示用）
    var isLoading = false
    var isManualSyncing = false
    var pendingDelete: AlarmEvent?
    var pendingComplete: AlarmEvent?
    private var deleteTimer: Timer?
    private var completeTimer: Timer?

    // MARK: - UI状態
    var isEventListExpanded = false
    var isUpcomingListExpanded = false
    var showMicSheet = false
    var showManualInput = false
    var showSettings = false
    var showCalendarImport = false
    var confirmationMessage: String?

    // MARK: - フクロウ状態
    var owlState: OwlState = .normal
    private var owlTapCount = 0
    private var owlTapLastTime: Date = .distantPast

    // MARK: - シェイク状態
    var showShakeToast = false
    var shakeMessage: String = ""

    // MARK: - 依存
    private let calendarProvider: CalendarProviding
    private let eventStore: AlarmEventStore
    private let syncEngine: SyncEngine
    private var appState: AppState?
    private var screenHeight: CGFloat = 0

    init(
        calendarProvider: CalendarProviding? = nil,
        eventStore: AlarmEventStore? = nil,
        syncEngine: SyncEngine? = nil
    ) {
        self.calendarProvider = calendarProvider ?? AppleCalendarProvider()
        self.eventStore = eventStore ?? .shared
        self.syncEngine = syncEngine ?? SyncEngine()
    }

    func bindAppStateIfNeeded(_ appState: AppState) {
        if self.appState == nil {
            self.appState = appState
        }
    }

    func updateScreenHeightIfNeeded(_ height: CGFloat) {
        guard height > 0 else { return }
        screenHeight = height
    }

    func dismissPresentedSheets() {
        showMicSheet = false
        showManualInput = false
        showSettings = false
    }

    // MARK: - 計算プロパティ: 予定リスト

    /// DynamicType extreme 時に動的に件数を算出
    var maxVisibleEventCount: Int {
        let sizeCategory = UIApplication.shared.preferredContentSizeCategory
        let isExtremeSize = sizeCategory >= .accessibilityLarge
        if isExtremeSize {
            let availableHeight = (screenHeight > 0 ? screenHeight : 812) * 0.5
            return max(1, Int(availableHeight / ComponentSize.eventRow))
        }
        return 3
    }

    /// 未完了の今日の予定（表示対象）
    /// completionStatus が .completed / .skipped / .missed のものを除外
    /// .awaitingResponse は通知済み未対応なので未完了側に残す（過去時刻でも表示）
    /// P-9-14: ToDoタスクは最上部に表示（時刻に関係なく）
    private var incompleteTodayEvents: [AlarmEvent] {
        let todos = events.filter { $0.isToDo && $0.completionStatus == nil }
        let timed = events.filter { !$0.isToDo && (
            // 未発火スケジュール済み（nil）または反応待ち（awaitingResponse）
            $0.completionStatus == nil || $0.completionStatus == .awaitingResponse
        )}
        return todos + timed
    }

    /// 上部の特別席に表示する予定
    var featuredEvents: [AlarmEvent] {
        guard let nextAlarm else { return [] }
        return [nextAlarm]
    }

    private var listTodayEvents: [AlarmEvent] {
        let featuredIDs = Set(featuredEvents.map(\.id))
        return incompleteTodayEvents.filter { !featuredIDs.contains($0.id) }
    }

    /// 画面に表示する予定（折りたたみ考慮済み）
    var visibleEvents: [AlarmEvent] {
        if isEventListExpanded {
            return listTodayEvents
        }
        return Array(listTodayEvents.prefix(maxVisibleEventCount))
    }

    /// 折りたたまれている件数
    var hiddenEventCount: Int {
        max(0, listTodayEvents.count - maxVisibleEventCount)
    }

    /// 折りたたみ状態で「残り○件を表示」ボタンを出すか
    var shouldShowExpandButton: Bool {
        !isEventListExpanded && hiddenEventCount > 0
    }

    /// 展開状態で「折りたたむ」ボタンを出すか
    var shouldShowCollapseButton: Bool {
        isEventListExpanded && hiddenEventCount > 0
    }

    /// 完了済み・スキップ済みの今日の予定（リスト下部に表示）
    /// .completed / .skipped / .missed のみ完了扱い。
    /// .awaitingResponse や nil は完了扱いしない（fireDate による後方互換ロジックを廃止）
    var completedTodayEvents: [AlarmEvent] {
        events.filter {
            guard let status = $0.completionStatus else { return false }
            return status != .awaitingResponse
        }
    }

    /// 明日以降の予定（最大2件）
    private static let upcomingDefaultCount = 2

    var tomorrowEvents: [AlarmEvent] {
        if isUpcomingListExpanded {
            return upcomingEvents
        }
        return Array(upcomingEvents.prefix(Self.upcomingDefaultCount))
    }

    var hiddenUpcomingCount: Int {
        max(0, upcomingEvents.count - Self.upcomingDefaultCount)
    }

    var shouldShowUpcomingExpandButton: Bool {
        !isUpcomingListExpanded && hiddenUpcomingCount > 0
    }

    var shouldShowUpcomingCollapseButton: Bool {
        isUpcomingListExpanded && hiddenUpcomingCount > 0
    }

    /// 次の予定（カウントダウン用）
    var nextAlarm: AlarmEvent? {
        events
            .filter { !$0.isToDo && $0.completionStatus == nil && $0.fireDate > Date() }
            .min(by: { $0.fireDate < $1.fireDate })
    }

    // MARK: - 計算プロパティ: 空状態メッセージ

    var emptyStateInfo: (message: String, ctaLabel: String) {
        let total = events.count
        let completed = completedTodayEvents.count
        let skipped = events.filter { $0.completionStatus == .skipped }.count

        if total == 0 {
            return ("🌸 今日はのんびり過ごしてね", "🎤 予定を追加する")
        } else if skipped > 0 {
            // スキップを先に評価（全完了でもスキップが含まれる場合はこちら優先）
            return ("🍵 今日は無理せず休もう。明日は明日の風が吹くよ 🦉", "🦉 体調が戻ったら教えてね")
        } else if completed == total {
            return ("🎉 お疲れ様！全部終わったよ！", "🌙 明日の予定も追加する？")
        }
        return ("🌸 今日はのんびり過ごしてね", "🎤 予定を追加する")
    }

    // MARK: - 計算プロパティ: あいさつ

    var greeting: String {
        // フクロウ名を先頭に添えるパターンと添えないパターンを混在させる
        // （毎回「○○だよ！」にすると単調になるため、約半数のみ名前入り）
        let name = appState?.owlName ?? "ふくろう"
        let greetings: [TimeSlot: [OwlState: [String]]] = [
            .morning: [
                .normal:     [
                    "おはようございます！",
                    "\(name)だよ！今日もいい朝ですね",
                    "今日もいい1日にしようね",
                    "朝ごはんは食べた？",
                    "今日もよろしくね！",
                    "いい朝だね、\(name)も目が覚めてきたよ",
                ],
                .happy:      [
                    "わーい、おはよう！",
                    "\(name)だよ！今日も一緒に頑張ろうね！",
                    "今日も元気に行こう！",
                    "うれしいな、おはよう！",
                    "いい朝だね！",
                    "\(name)、今日も楽しみだよ！",
                ],
                .worried:    [
                    "大丈夫？ちゃんと起きられた？",
                    "\(name)だよ。何か急ぎの予定あったっけ？",
                    "今日の予定、確認できてる？",
                    "忘れ物ない？出かける前にチェックしてね",
                    "急ぎの予定、ギリギリじゃない？",
                    "朝から焦らなくていいよ、落ち着いてね",
                ],
                .sleepy:     [
                    "\(name)も眠い…おはよう…",
                    "ゆっくり目が覚めてきたかな？",
                    "まだ眠そう…コーヒー飲んだ？",
                    "のんびり起きていいよ",
                    "目が覚めたら教えてね",
                    "眠いときは無理しないでね",
                ],
                .sunglasses: [
                    "おはよう、今日もクールにいこう 😎",
                    "\(name)だよ！朝からイカしてるね！",
                    "朝からカッコいい！ 😎",
                    "今日もスタイリッシュにいこう！",
                    "クールな朝の始まりだ 😎",
                    "\(name)も朝からテンション上がるよ！ 😎",
                ],
            ],
            .afternoon: [
                .normal:     [
                    "\(name)だよ！こんにちは！",
                    "お昼はゆっくりできてる？",
                    "午後もよろしくね！",
                    "いい午後だね！",
                    "ちゃんとお昼ご飯食べた？",
                    "午後も\(name)と一緒だよ！",
                ],
                .happy:      [
                    "今日も調子いいね！",
                    "\(name)だよ！午後もがんばろう！",
                    "すごいね、元気いっぱい！",
                    "一緒に午後も乗り越えよう！",
                    "うれしそうだね！\(name)も嬉しい",
                    "今日はいい1日になりそうだね！",
                ],
                .worried:    [
                    "急ぎの予定、忘れてない？",
                    "\(name)が心配してるよ。少し休んだ方がいいかも",
                    "今日の予定はちゃんと進んでる？",
                    "無理しすぎてない？",
                    "ちょっと疲れてない？休憩もいいよ",
                    "大丈夫？水分はちゃんと取ってね",
                ],
                .sleepy:     [
                    "\(name)もお昼眠い…",
                    "ちょっとひと休みしようか",
                    "お昼過ぎは眠くなるよね",
                    "少し目を閉じてみよっか",
                    "眠いときは無理しないでね",
                    "短い昼寝もいいかもね",
                ],
                .sunglasses: [
                    "\(name)だよ！午後もクールに！ 😎",
                    "サングラス似合うでしょ？",
                    "午後もかっこよくいこう 😎",
                    "スタイル崩さずいこうね！",
                    "クールなままでいようね 😎",
                    "午後もイカしてるね！ 😎",
                ],
            ],
            .evening: [
                .normal:     [
                    "\(name)だよ！お疲れ様です！",
                    "今日もよく頑張ったね",
                    "夕方になったね、少し休んで",
                    "今日も1日お疲れ様！",
                    "夕方の風が気持ちいいね",
                    "\(name)も一緒にのんびりしようか",
                ],
                .happy:      [
                    "夕方も元気だね！",
                    "\(name)も嬉しいな！今日一日よく頑張ったよ！",
                    "いい顔してるね！",
                    "今日もよく頑張ったね、えらい！",
                    "夕暮れ、好きだな",
                    "今日もいい1日だったね！",
                ],
                .worried:    [
                    "まだ終わってない予定ある？",
                    "\(name)だよ。急がなくていいよ、ゆっくりね",
                    "夜遅くなりそう？大丈夫？",
                    "疲れてない？無理しないでね",
                    "明日の準備、余裕あるうちにしておこうね",
                    "焦らなくていいよ、一つずつやっていこう",
                ],
                .sleepy:     [
                    "\(name)も眠くなってきた…",
                    "今日はもうゆっくりしてね",
                    "夕方は眠くなるよね",
                    "ゆっくりお風呂に入ってね",
                    "今日のうちに早めに休もうね",
                    "疲れたら無理せず休んでいいよ",
                ],
                .sunglasses: [
                    "夕暮れもクール 😎",
                    "\(name)だよ！夜もかっこよくいこう！",
                    "夕暮れのサングラス、最高 😎",
                    "かっこいい夕方だね！",
                    "夕焼けとサングラス、似合うよ 😎",
                    "\(name)、夕方もイカしてるよ！ 😎",
                ],
            ],
            .night: [
                .normal:     [
                    "\(name)だよ！こんばんは！",
                    "今夜もお疲れ様",
                    "夜は静かでいいね",
                    "こんばんは！ゆっくりしてね",
                    "今日も一日ありがとう",
                    "\(name)も一緒に夜を過ごすよ",
                ],
                .happy:      [
                    "夜も元気！？すごいね",
                    "\(name)も嬉しいな！今日もよく頑張ったね！",
                    "夜も楽しそうだね！",
                    "いい夜だね！",
                    "今日もよく頑張ったよ、えらい！",
                    "夜も笑顔でいいね！",
                ],
                .worried:    [
                    "遅くまで起きてて大丈夫？",
                    "\(name)が心配してるよ。明日の予定は確認できてる？",
                    "夜更かしはほどほどにね",
                    "明日の準備、できてる？",
                    "ちゃんと眠れそう？",
                    "夜中に無理しないでね",
                ],
                .sleepy:     [
                    "\(name)も眠い…おやすみ…",
                    "早めに休んでね",
                    "そろそろ寝る時間かな",
                    "おやすみなさい、ゆっくり休んでね",
                    "今日もお疲れ様、もう眠っていいよ",
                    "ぐっすり眠れるといいね",
                ],
                .sunglasses: [
                    "\(name)だよ！夜もクールに 😎",
                    "夜型もかっこいいね",
                    "深夜もスタイリッシュ 😎",
                    "\(name)、夜もクールだよ！",
                    "夜更かしも、クールにいこう 😎",
                    "夜の\(name)、イカしてるね 😎",
                ],
            ],
        ]
        let slot = TimeSlot.current
        let candidates = greetings[slot]?[owlState] ?? ["\(name)だよ！こんにちは！"]
        guard !candidates.isEmpty else { return "こんにちは！" }
        let daySeed = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let hourSeed = Calendar.current.component(.hour, from: Date())
        let stateSeed: Int = switch owlState {
        case .normal: 0
        case .happy: 1
        case .worried: 2
        case .sleepy: 3
        case .sunglasses: 4
        }
        let index = abs(daySeed + hourSeed + stateSeed) % candidates.count
        return candidates[index]
    }

    // MARK: - データ取得

    func loadEvents() async {
        isLoading = true
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let allEvents = eventStore.loadAll()
        events = allEvents
            .filter { $0.fireDate >= startOfToday && $0.fireDate < startOfTomorrow }
            .sorted { $0.fireDate < $1.fireDate }
        upcomingEvents = deduplicatedUpcoming(from: allEvents, startingFrom: startOfTomorrow)
        isLoading = false
        updateOwlState()
    }

    func performManualSync() async {
        guard !isManualSyncing else {
            return
        }
        isManualSyncing = true
        defer { isManualSyncing = false }

        await OfflineActionQueue.shared.flush()
        await syncEngine.performFullSync()
        if appState?.subscriptionTier == .pro {
            _ = await syncEngine.syncRemoteEvents()
        }
        await loadEvents()
    }

    private func deduplicatedUpcoming(from allEvents: [AlarmEvent], startingFrom: Date) -> [AlarmEvent] {
        var seenGroupIDs = Set<UUID>()
        var result: [AlarmEvent] = []
        for event in allEvents
            .filter({ !$0.isToDo && $0.completionStatus == nil && $0.fireDate >= startingFrom })
            .sorted(by: { $0.fireDate < $1.fireDate }) {
            if let groupID = event.recurrenceGroupID {
                if seenGroupIDs.contains(groupID) { continue }
                seenGroupIDs.insert(groupID)
            }
            result.append(event)
        }
        return result
    }

    // MARK: - 予定削除（3秒Undo付き）

    func deleteEvent(_ alarm: AlarmEvent) async {
        completeTimer?.invalidate()
        completeTimer = nil
        if let pending = pendingComplete {
            await commitComplete(pending)
        }
        pendingComplete = nil
        // タイマーを先に止めてから await（タイマー発火との競合を防ぐ）
        deleteTimer?.invalidate()
        deleteTimer = nil
        // 連続削除対応: 前の pendingDelete が残っている場合は即座にコミット削除する。
        // これにより「3秒以内に2件削除」しても前のアラームがゾンビ化しない。
        // 副作用: 2件目の削除操作が来た瞬間に1件目の Undo 猶予が強制終了する（仕様として許容）。
        if let pending = pendingDelete {
            await commitDelete(pending)
        }
        events.removeAll { $0.id == alarm.id }
        pendingDelete = alarm
        let alarmID = alarm.id
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let pending = self.pendingDelete, pending.id == alarmID else { return }
                await self.commitDelete(pending)
            }
        }
    }

    func undoDelete() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        if let alarm = pendingDelete {
            events.append(alarm)
            events.sort { $0.fireDate < $1.fireDate }
        }
        pendingDelete = nil
    }

    func prepareCompleteEvent(_ alarm: AlarmEvent) async {
        guard alarm.completionStatus == nil else { return }

        deleteTimer?.invalidate()
        deleteTimer = nil
        if let pending = pendingDelete {
            await commitDelete(pending)
        }
        pendingDelete = nil

        completeTimer?.invalidate()
        completeTimer = nil
        if let pending = pendingComplete {
            await commitComplete(pending)
        }

        pendingComplete = alarm

        if let index = events.firstIndex(where: { $0.id == alarm.id }) {
            var completedPreview = alarm
            completedPreview.completionStatus = .completed
            events[index] = completedPreview
        } else {
            upcomingEvents.removeAll { $0.id == alarm.id }
        }

        let alarmID = alarm.id
        completeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let pending = self.pendingComplete, pending.id == alarmID else { return }
                await self.commitComplete(pending)
            }
        }
    }

    func undoComplete() {
        completeTimer?.invalidate()
        completeTimer = nil
        pendingComplete = nil
        Task { await loadEvents() }
    }

    func completeEvent(_ alarm: AlarmEvent) async {
        await prepareCompleteEvent(alarm)
    }

    /// ToDoタスクを今日スキップして翌日に繰り越す
    func skipAndCarryOverToDo(_ alarm: AlarmEvent) {
        // 元のToDoをスキップ済みにする
        var skipped = alarm
        skipped.completionStatus = .skipped
        eventStore.save(skipped)

        // 翌日の00:00で同じ内容のToDoを新規作成
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1,
            to: Calendar.current.startOfDay(for: Date())
        )!
        let carried = AlarmEvent(
            title: alarm.title,
            fireDate: tomorrow,
            calendarIdentifier: alarm.calendarIdentifier,
            voiceCharacter: alarm.voiceCharacter,
            eventEmoji: alarm.eventEmoji,
            isToDo: true
        )
        eventStore.save(carried)

        Task { await loadEvents() }
        showConfirmation("明日に繰り越したよ 🦉")
    }

    func deleteRecurringSeries(_ alarm: AlarmEvent) async {
        guard let groupID = alarm.recurrenceGroupID else {
            await deleteEvent(alarm)
            return
        }

        let groupedEvents = eventStore.loadAll().filter { $0.recurrenceGroupID == groupID }
        for groupedEvent in groupedEvents {
            if let ekID = groupedEvent.eventKitIdentifier {
                try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
            }
            let idsToCancel = groupedEvent.alarmKitIdentifiers.isEmpty
                ? [groupedEvent.alarmKitIdentifier].compactMap { $0 }
                : groupedEvent.alarmKitIdentifiers
            if !idsToCancel.isEmpty {
                try? await AlarmKitScheduler().cancelAll(alarmKitIDs: idsToCancel)
            }
            VoiceFileGenerator().deleteAudio(alarmID: groupedEvent.id)
            eventStore.delete(id: groupedEvent.id)
        }

        pendingDelete = nil
        await loadEvents()
        showConfirmation("繰り返し予定をまとめて削除したよ")
    }

    private func commitDelete(_ alarm: AlarmEvent) async {
        if alarm.id == pendingDelete?.id { pendingDelete = nil }
        if let ekID = alarm.eventKitIdentifier {
            try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
        }
        let idsToCancel = alarm.alarmKitIdentifiers.isEmpty
            ? [alarm.alarmKitIdentifier].compactMap { $0 }
            : alarm.alarmKitIdentifiers
        if !idsToCancel.isEmpty {
            try? await AlarmKitScheduler().cancelAll(alarmKitIDs: idsToCancel)
        }
        // 家族から送られた予定の場合は見守り側にキャンセルを通知する
        if let remoteEventId = alarm.remoteEventId {
            try? await FamilyRemoteService.shared.cancelRemoteEvent(id: remoteEventId)
        }
        VoiceFileGenerator().deleteAudio(alarmID: alarm.id)
        eventStore.delete(id: alarm.id)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func commitComplete(_ alarm: AlarmEvent) async {
        if alarm.id == pendingComplete?.id { pendingComplete = nil }

        var updated = alarm
        updated.completionStatus = .completed
        updated.alarmKitIdentifier = nil
        updated.alarmKitIdentifiers = []
        updated.alarmKitMinutesMap = [:]

        let idsToCancel = alarm.alarmKitIdentifiers.isEmpty
            ? [alarm.alarmKitIdentifier].compactMap { $0 }
            : alarm.alarmKitIdentifiers
        if !idsToCancel.isEmpty {
            try? await AlarmKitScheduler().cancelAll(alarmKitIDs: idsToCancel)
        }

        if let remoteEventId = alarm.remoteEventId {
            await OfflineActionQueue.shared.sendOrEnqueueStatusUpdate(
                eventID: remoteEventId,
                status: "completed"
            )
        }

        eventStore.save(updated)
        appState?.addXP(10)
        await loadEvents()
        showConfirmation("「\(alarm.title)」を完了にしたよ")
    }

    // MARK: - フクロウ状態更新

    private func updateOwlState() {
        guard let next = nextAlarm else {
            owlState = .sleepy
            return
        }
        let minutes = next.fireDate.timeIntervalSinceNow / 60
        if minutes < 5 {
            owlState = .worried
        } else {
            owlState = .normal
        }
    }

    // MARK: - フクロウインタラクション

    func handleOwlTap() {
        // 10回タップ隠しイベント（1分以内）
        let now = Date()
        if now.timeIntervalSince(owlTapLastTime) > 60 {
            owlTapCount = 0
        }
        owlTapCount += 1
        owlTapLastTime = now

        if owlTapCount >= 10 {
            owlState = .sunglasses
            owlTapCount = 0
            showConfirmation("実はカッコいいやつだよ 😎")
            return
        }

        // ランダム4種（40%/30%/20%/10%）
        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<40:
            owlState = .happy
            Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                owlState = .normal
            }
        case 40..<70:
            showConfirmation("つつかれた！🦉")
        case 70..<90:
            // 首傾けは View 側で owlState 変化なしで独自アニメ
            // ViewModel は何もしない（View で .rotationEffect を使う）
            break
        default:
            // 1日1回のみ
            let key = "owlSpecialMessageDate"
            let lastDate = UserDefaults.standard.object(forKey: key) as? Date ?? .distantPast
            if !Calendar.current.isDateInToday(lastDate) {
                UserDefaults.standard.set(Date(), forKey: key)
                showConfirmation("今日も一緒にがんばろうね 🌟")
            }
        }
    }

    func handleOwlShake() {
        owlState = .worried
        let messages = ["ふらふら…🌀", "酔いそうだよ！", "もう少しやさしくして！", "わあ、地震かと思った"]
        let msg = messages.randomElement() ?? "ふらふら…"
        shakeMessage = msg
        showShakeToast = true
        ToastWindowManager.shared.show(ToastMessage(text: msg, style: .owlTip))
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showShakeToast = false
            owlState = .normal
        }
    }

    // MARK: - XP管理

    nonisolated static func evolutionStage(for xp: Int) -> Int {
        switch xp {
        case 0..<100:    return 0
        case 100..<500:  return 1
        case 500..<1000: return 2
        default:         return 3
        }
    }

    /// XPに応じた進化段階
    var owlEvolutionStage: Int {
        Self.evolutionStage(for: appState?.owlXP ?? 0)
    }

    /// XP × owlState に応じたふくろうアセット名を返す
    /// フォールバック: normal → OwlIcon の順
    func owlImageName(emotion: OwlState? = nil) -> String {
        let stage = owlEvolutionStage
        let emotionKey = (emotion ?? owlState).assetKey
        let name = "owl_stage\(stage)_\(emotionKey)"
        if UIImage(named: name) != nil { return name }
        // フォールバック1: normal
        let normalName = "owl_stage\(stage)_normal"
        if UIImage(named: normalName) != nil { return normalName }
        // フォールバック2: 旧アセット
        return "OwlIcon"
    }

    // 後方互換: 旧プロパティ参照箇所用（削除可能になったら消す）
    var owlImageName: String {
        owlImageName()
    }

    // MARK: - デイリーミニタスク（P-1-5）

    /// 日替わりのミニタスク候補（ランダム選出）
    private let miniTaskCandidates = [
        "🍵 お水飲んだ？",
        "🧘 ストレッチした？",
        "🪟 窓を開けて空気を入れ替えた？",
        "😊 今日ひとつ、いいことあった？",
        "🌿 深呼吸してみよう",
        "☀️ 少し日光を浴びた？",
        "📝 今日のよかったことを1つ思い出せる？",
    ]

    /// 今日のミニタスク（日付からシードを決めて固定）
    var dailyMiniTask: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return miniTaskCandidates[dayOfYear % miniTaskCandidates.count]
    }

    /// 今日すでにミニタスクを完了したか
    var isMiniTaskCompletedToday: Bool {
        let lastDate = UserDefaults.standard.object(forKey: "miniTaskCompletedDate") as? Date ?? .distantPast
        return Calendar.current.isDateInToday(lastDate)
    }

    /// ミニタスクを完了する（+5XP・1日1回）
    func completeDailyMiniTask() {
        guard !isMiniTaskCompletedToday else { return }
        UserDefaults.standard.set(Date(), forKey: "miniTaskCompletedDate")
        appState?.addXP(5)
        showConfirmation("🦉 えらい！+5ポイントだよ")
    }

    // MARK: - プライベートヘルパー

    private func showConfirmation(_ message: String) {
        // ToastWindowManager 経由で表示（RingingView上にも表示可能）
        ToastWindowManager.shared.show(ToastMessage(text: message, style: .owlTip))
        // 後方互換: confirmationMessage も更新してアニメーションを維持
        confirmationMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            confirmationMessage = nil
        }
    }
}
