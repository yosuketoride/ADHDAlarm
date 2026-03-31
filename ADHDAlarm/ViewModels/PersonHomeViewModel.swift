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
    private var deleteTimer: Timer?

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

    init(
        calendarProvider: CalendarProviding = AppleCalendarProvider(),
        eventStore: AlarmEventStore = .shared
    ) {
        self.calendarProvider = calendarProvider
        self.eventStore = eventStore
    }

    // MARK: - 計算プロパティ: 予定リスト

    /// DynamicType extreme 時に動的に件数を算出
    var maxVisibleEventCount: Int {
        let sizeCategory = UIApplication.shared.preferredContentSizeCategory
        let isExtremeSize = sizeCategory >= .accessibilityLarge
        if isExtremeSize {
            let availableHeight = UIScreen.main.bounds.height * 0.5
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
        events.filter { $0.fireDate > Date() }.min(by: { $0.fireDate < $1.fireDate })
    }

    // MARK: - 計算プロパティ: 空状態メッセージ

    var emptyStateInfo: (message: String, ctaLabel: String) {
        let total = events.count
        let completed = completedTodayEvents.count
        let skipped = events.filter { $0.completionStatus == .skipped }.count

        if total == 0 {
            return ("🌸 今日はのんびり過ごしてね", "🎤 何か予定を追加してみよう")
        } else if skipped > 0 {
            // スキップを先に評価（全完了でもスキップが含まれる場合はこちら優先）
            return ("🍵 今日は無理せず休もう。明日は明日の風が吹くよ 🦉", "🦉 体調が戻ったら声で教えてね")
        } else if completed == total {
            return ("🎉 お疲れ様！全部終わったよ！ふくろうも誇らしいよ", "🌙 明日の予定を追加しておく？")
        }
        return ("🌸 今日はのんびり過ごしてね", "🎤 何か予定を追加してみよう")
    }

    // MARK: - 計算プロパティ: あいさつ

    var greeting: String {
        let greetings: [TimeSlot: [OwlState: [String]]] = [
            .morning: [
                .normal:     ["おはようございます！", "今日もいい朝ですね"],
                .happy:      ["わーい、おはよう！", "今日も一緒に頑張ろうね！"],
                .worried:    ["大丈夫？ちゃんと起きられた？", "何か急ぎの予定あったっけ？"],
                .sleepy:     ["ふあ…おはよう…", "ゆっくり目が覚めてきたかな？"],
                .sunglasses: ["おはよう、今日もクールにいこう 😎", "朝からイカしてるね！"],
            ],
            .afternoon: [
                .normal:     ["こんにちは！", "お昼はゆっくりできてる？"],
                .happy:      ["今日も調子いいね！", "午後もがんばろう！"],
                .worried:    ["急ぎの予定、忘れてない？", "少し休んだ方がいいかも"],
                .sleepy:     ["お昼眠いね…", "ちょっとひと休みしようか"],
                .sunglasses: ["午後もクールに！ 😎", "サングラス似合うでしょ？"],
            ],
            .evening: [
                .normal:     ["お疲れ様です！", "今日もよく頑張ったね"],
                .happy:      ["夕方も元気だね！", "今日一日よく頑張ったよ！"],
                .worried:    ["まだ終わってない予定ある？", "急がなくていいよ、ゆっくりね"],
                .sleepy:     ["夕方だね…そろそろ眠いかな", "今日はもうゆっくりしてね"],
                .sunglasses: ["夕暮れもクール 😎", "夜もかっこよくいこう！"],
            ],
            .night: [
                .normal:     ["こんばんは！", "今夜もお疲れ様"],
                .happy:      ["夜も元気！？すごいね", "今日もよく頑張ったね！"],
                .worried:    ["遅くまで起きてて大丈夫？", "明日の予定は確認できてる？"],
                .sleepy:     ["ふあ…おやすみ…", "早めに休んでね"],
                .sunglasses: ["夜もクールに 😎", "夜型もかっこいいね"],
            ],
        ]
        let slot = TimeSlot.current
        let candidates = greetings[slot]?[owlState] ?? ["こんにちは！"]
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
        for event in allEvents.filter({ $0.fireDate >= startingFrom }).sorted(by: { $0.fireDate < $1.fireDate }) {
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
        // タイマーを先に止めてから await（タイマー発火との競合を防ぐ）
        deleteTimer?.invalidate()
        deleteTimer = nil
        if let pending = pendingDelete {
            await commitDelete(pending)
        }
        events.removeAll { $0.id == alarm.id }
        pendingDelete = alarm
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self, let pending = self.pendingDelete, pending.id == alarm.id else { return }
            Task { await self.commitDelete(pending) }
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

    func addXP(_ amount: Int) {
        let cap = 50
        let defaults = UserDefaults.standard
        // 日付が変わっていたら今日のXPをリセット
        let lastDate = defaults.object(forKey: Constants.Keys.owlXPLastDate) as? Date ?? .distantPast
        var dailyAdded = defaults.integer(forKey: Constants.Keys.owlXPToday)
        if !Calendar.current.isDateInToday(lastDate) {
            dailyAdded = 0
            defaults.set(0, forKey: Constants.Keys.owlXPToday)
        }
        let current = defaults.integer(forKey: Constants.Keys.owlXP)
        let actual = min(amount, cap - dailyAdded)
        guard actual > 0 else { return }
        defaults.set(current + actual, forKey: Constants.Keys.owlXP)
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
