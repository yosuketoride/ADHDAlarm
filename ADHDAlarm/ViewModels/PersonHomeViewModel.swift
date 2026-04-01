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
    var pendingDelete: AlarmEvent?
    var pendingComplete: AlarmEvent?
    private var deleteTimer: Timer?
    private var completeTimer: Timer?

    // MARK: - UI状態
    var isEventListExpanded = false
    var showMicSheet = false
    var showManualInput = false
    var showSettings = false
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
    private var appState: AppState?
    private var screenHeight: CGFloat = 0

    init(
        calendarProvider: CalendarProviding? = nil,
        eventStore: AlarmEventStore? = nil
    ) {
        self.calendarProvider = calendarProvider ?? AppleCalendarProvider()
        self.eventStore = eventStore ?? .shared
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
    /// completionStatus が設定済みのものは明示的に完了 or スキップ → 未完了リストから除外
    /// P-9-14: ToDoタスクは最上部に表示（時刻に関係なく）
    private var incompleteTodayEvents: [AlarmEvent] {
        let todos = events.filter { $0.isToDo && $0.completionStatus == nil }
        let timed = events.filter { !$0.isToDo && $0.completionStatus == nil && $0.fireDate >= Date() }
        return todos + timed
    }

    /// 画面に表示する予定（折りたたみ考慮済み）
    var visibleEvents: [AlarmEvent] {
        if isEventListExpanded {
            return incompleteTodayEvents
        }
        return Array(incompleteTodayEvents.prefix(maxVisibleEventCount))
    }

    /// 折りたたまれている件数
    var hiddenEventCount: Int {
        max(0, incompleteTodayEvents.count - maxVisibleEventCount)
    }

    /// 完了済み・スキップ済みの今日の予定（リスト下部に表示）
    /// completionStatus が設定済み、または fireDate 過ぎたもの（後方互換プロキシ）
    var completedTodayEvents: [AlarmEvent] {
        events.filter { $0.completionStatus != nil || $0.fireDate < Date() }
    }

    /// 明日以降の予定（最大2件）
    var tomorrowEvents: [AlarmEvent] {
        Array(upcomingEvents.prefix(2))
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
            return ("🎉 お疲れ様！全部終わったよ！ふくろうも誇らしいよ", "🌙 明日の予定も追加する？")
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
                .normal:     ["おはようございます！", "\(name)だよ！今日もいい朝ですね"],
                .happy:      ["わーい、おはよう！", "\(name)だよ！今日も一緒に頑張ろうね！"],
                .worried:    ["大丈夫？ちゃんと起きられた？", "\(name)だよ。何か急ぎの予定あったっけ？"],
                .sleepy:     ["\(name)も眠い…おはよう…", "ゆっくり目が覚めてきたかな？"],
                .sunglasses: ["おはよう、今日もクールにいこう 😎", "\(name)だよ！朝からイカしてるね！"],
            ],
            .afternoon: [
                .normal:     ["\(name)だよ！こんにちは！", "お昼はゆっくりできてる？"],
                .happy:      ["今日も調子いいね！", "\(name)だよ！午後もがんばろう！"],
                .worried:    ["急ぎの予定、忘れてない？", "\(name)が心配してるよ。少し休んだ方がいいかも"],
                .sleepy:     ["\(name)もお昼眠い…", "ちょっとひと休みしようか"],
                .sunglasses: ["\(name)だよ！午後もクールに！ 😎", "サングラス似合うでしょ？"],
            ],
            .evening: [
                .normal:     ["\(name)だよ！お疲れ様です！", "今日もよく頑張ったね"],
                .happy:      ["夕方も元気だね！", "\(name)も嬉しいな！今日一日よく頑張ったよ！"],
                .worried:    ["まだ終わってない予定ある？", "\(name)だよ。急がなくていいよ、ゆっくりね"],
                .sleepy:     ["\(name)も眠くなってきた…", "今日はもうゆっくりしてね"],
                .sunglasses: ["夕暮れもクール 😎", "\(name)だよ！夜もかっこよくいこう！"],
            ],
            .night: [
                .normal:     ["\(name)だよ！こんばんは！", "今夜もお疲れ様"],
                .happy:      ["夜も元気！？すごいね", "\(name)も嬉しいな！今日もよく頑張ったね！"],
                .worried:    ["遅くまで起きてて大丈夫？", "\(name)が心配してるよ。明日の予定は確認できてる？"],
                .sleepy:     ["\(name)も眠い…おやすみ…", "早めに休んでね"],
                .sunglasses: ["\(name)だよ！夜もクールに 😎", "夜型もかっこいいね"],
            ],
        ]
        let slot = TimeSlot.current
        let candidates = greetings[slot]?[owlState] ?? ["\(name)だよ！こんにちは！"]
        return candidates.randomElement() ?? "こんにちは！"
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
            try? await FamilyRemoteService.shared.updateRemoteEventStatus(id: remoteEventId, status: "completed")
        }

        eventStore.save(updated)
        addXP(10)
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
        shakeMessage = messages.randomElement() ?? "ふらふら…"
        showShakeToast = true
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showShakeToast = false
            owlState = .normal
        }
    }

    // MARK: - XP管理

    /// XP量に応じたふくろうアセット名（owl_stage0〜3）
    /// アセットが存在しない場合は "OwlIcon" にフォールバックする
    var owlImageName: String {
        switch appState?.owlXP ?? 0 {
        case 0..<100:    return "owl_stage0"
        case 100..<500:  return "owl_stage1"
        case 500..<1000: return "owl_stage2"
        default:         return "owl_stage3"
        }
    }

    func addXP(_ amount: Int) {
        guard let appState else { return }
        let cap = 50
        let defaults = UserDefaults.standard
        // 日付が変わっていたら今日のXPをリセット
        let lastDate = defaults.object(forKey: Constants.Keys.owlXPLastDate) as? Date ?? .distantPast
        var dailyAdded = defaults.integer(forKey: Constants.Keys.owlXPToday)
        if !Calendar.current.isDateInToday(lastDate) {
            dailyAdded = 0
            defaults.set(0, forKey: Constants.Keys.owlXPToday)
        }
        let actual = min(amount, cap - dailyAdded)
        guard actual > 0 else { return }
        appState.owlXP += actual
        defaults.set(dailyAdded + actual, forKey: Constants.Keys.owlXPToday)
        defaults.set(Date(), forKey: Constants.Keys.owlXPLastDate)
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
        addXP(5)
        showConfirmation("🦉 えらい！+5ポイントだよ")
    }

    // MARK: - プライベートヘルパー

    private func showConfirmation(_ message: String) {
        confirmationMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            confirmationMessage = nil
        }
    }
}
