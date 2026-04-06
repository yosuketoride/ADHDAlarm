import Foundation
import Observation

// MARK: - CalendarImportViewModel

/// カレンダーから取り込む機能（PRO）のViewModel
@Observable @MainActor
final class CalendarImportViewModel {

    // MARK: - カレンダー選択

    /// 表示可能なカレンダー一覧（書き込み可能のみ）
    var availableCalendars: [CalendarInfo] = []
    /// 取り込み元として選択中のカレンダーID（空 = 全カレンダー）
    var selectedCalendarIDs: Set<String> = []

    // MARK: - 取り込み候補

    var candidates: [ImportCandidate] = []
    /// チェック済みのEKイベントID
    var selectedIDs: Set<String> = []
    /// 個別上書き分数（EKIdentifier → 分）。存在しない場合は bulkPreNotificationMinutes を使う
    var perEventMinutes: [String: Int] = [:]
    /// 全体の通知タイミング（分前）。デフォルト: ジャスト=0
    var bulkPreNotificationMinutes: Int = 0

    // MARK: - 状態

    enum LoadState {
        case idle
        case loading
        case noPermission   // EventKit権限なし
        case empty          // 候補ゼロ
        case loaded
        case error(String)
    }

    enum ImportResult {
        case success(String)            // タイトル
        case failure(String, String)    // タイトル、理由
    }

    var loadState: LoadState = .idle
    var isImporting = false
    var importResults: [ImportResult] = []

    // MARK: - 依存サービス

    private let calendarProvider: any CalendarProviding
    private let eventStore: AlarmEventStore
    private let permissionsService: PermissionsService
    private let scheduler: any AlarmScheduling
    private let voiceSynth: any VoiceSynthesizing

    // MARK: - Init

    init(
        calendarProvider: (any CalendarProviding)? = nil,
        eventStore: AlarmEventStore? = nil,
        permissionsService: PermissionsService? = nil,
        scheduler: (any AlarmScheduling)? = nil,
        voiceSynth: (any VoiceSynthesizing)? = nil
    ) {
        self.calendarProvider   = calendarProvider ?? AppleCalendarProvider()
        self.eventStore         = eventStore ?? .shared
        self.permissionsService = permissionsService ?? PermissionsService()
        self.scheduler          = scheduler ?? AlarmKitScheduler()
        self.voiceSynth         = voiceSynth ?? VoiceFileGenerator()
    }

    // MARK: - カレンダー選択ヘルパー

    /// カレンダーの選択状態を切り替える
    func toggleCalendar(_ id: String) {
        if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.remove(id)
        } else {
            selectedCalendarIDs.insert(id)
        }
    }

    /// 選択中カレンダーの要約テキスト（Menuラベル用）
    var selectedCalendarSummary: String {
        let selected = availableCalendars.filter { selectedCalendarIDs.contains($0.id) }
        if selected.isEmpty || selected.count == availableCalendars.count {
            return "すべてのカレンダー"
        }
        return selected.prefix(2).map { $0.title }.joined(separator: "、")
            + (selected.count > 2 ? " 他\(selected.count - 2)件" : "")
    }

    // MARK: - データ読み込み

    /// 取り込み候補を読み込む
    func load() async {
        loadState = .loading

        // 権限チェック
        guard permissionsService.isCalendarAuthorized else {
            loadState = .noPermission
            return
        }

        // 書き込み可能カレンダー一覧を取得（カレンダー選択UIに使用）
        availableCalendars = (try? await calendarProvider.availableCalendars()) ?? []
        if selectedCalendarIDs.isEmpty {
            // デフォルト: 全カレンダーを選択状態にする
            selectedCalendarIDs = Set(availableCalendars.map { $0.id })
        }

        // 取り込み済みIDを除外対象として収集
        let alreadyImported = Set(eventStore.loadAll().compactMap { $0.eventKitIdentifier })
        let to = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        // 選択がすべて揃っている場合は nil（= 全カレンダー）を渡す
        let calIDs: Set<String>? = selectedCalendarIDs.isEmpty ? nil : selectedCalendarIDs

        do {
            candidates = try await calendarProvider.fetchImportCandidates(
                from: Date(),
                to: to,
                excludingEKIdentifiers: alreadyImported,
                calendarIdentifiers: calIDs
            )
            selectedIDs = Set(candidates.map { $0.id })  // デフォルト全選択
            loadState = candidates.isEmpty ? .empty : .loaded
        } catch {
            loadState = .error("予定の読み込みに失敗しました")
        }
    }

    /// カレンダー選択が変わったときに候補を再読み込みする
    func reloadCandidates() async {
        let alreadyImported = Set(eventStore.loadAll().compactMap { $0.eventKitIdentifier })
        let to = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let calIDs: Set<String>? = selectedCalendarIDs.isEmpty ? nil : selectedCalendarIDs

        guard case .loaded = loadState else { return }

        candidates = (try? await calendarProvider.fetchImportCandidates(
            from: Date(),
            to: to,
            excludingEKIdentifiers: alreadyImported,
            calendarIdentifiers: calIDs
        )) ?? candidates

        // 選択リストを更新候補に合わせてクリーンアップ
        let newIDs = Set(candidates.map { $0.id })
        selectedIDs = selectedIDs.intersection(newIDs)
        loadState = candidates.isEmpty ? .empty : .loaded
    }

    // MARK: - 全選択 / 全解除

    func selectAll() { selectedIDs = Set(candidates.map { $0.id }) }
    func deselectAll() { selectedIDs = [] }

    // MARK: - 取り込み実行

    func importSelected(appState: AppState) async {
        guard !isImporting else { return }
        isImporting = true
        importResults = []

        for id in selectedIDs {
            guard let candidate = candidates.first(where: { $0.id == id }) else { continue }

            let alarmID = UUID()
            let minutes = perEventMinutes[id] ?? bulkPreNotificationMinutes

            var alarm = AlarmEvent(
                id: alarmID,
                title: candidate.title,
                fireDate: candidate.startDate,
                preNotificationMinutes: minutes,
                eventKitIdentifier: candidate.id,
                calendarIdentifier: candidate.calendarIdentifier
            )

            // Step 1: AlarmKit 登録（失敗 → failure・副作用なし）
            guard let alarmKitID = try? await scheduler.schedule(alarm) else {
                importResults.append(.failure(candidate.title, "通知の設定に失敗しました"))
                continue
            }
            alarm.alarmKitIdentifier = alarmKitID

            // Step 2: EKEvent にマーカー追記（失敗 → AlarmKit をキャンセルしてロールバック）
            do {
                try await calendarProvider.appendMarker(to: candidate.id, alarmID: alarmID)
            } catch {
                try? await scheduler.cancel(alarmKitID: alarmKitID)
                importResults.append(.failure(candidate.title, "カレンダーへの書き込みに失敗しました"))
                continue
            }

            // Step 3: ローカル保存（throwsなし）
            eventStore.save(alarm)

            // Step 4: 音声生成（UIフリーズ防止のため fire-and-forget）
            Task {
                let preText = minutes > 0 ? "あと\(minutes)分で" : ""
                let text = "お時間です。\(preText)\(candidate.title)のご予定ですよ。"
                try? await voiceSynth.generateAudio(
                    text: text,
                    character: appState.voiceCharacter,
                    alarmID: alarmID,
                    eventTitle: candidate.title
                )
            }

            importResults.append(.success(candidate.title))
        }

        isImporting = false
    }

    // MARK: - 結果集計

    var successCount: Int { importResults.filter { if case .success = $0 { return true }; return false }.count }
    var failureCount: Int { importResults.filter { if case .failure = $0 { return true }; return false }.count }

    var toastMessage: String {
        let total = successCount + failureCount
        if failureCount == 0 {
            return "\(successCount)件の予定を取り込んだよ！🦉"
        } else if successCount == 0 {
            return "取り込みに失敗しました 🦉"
        } else {
            return "\(total)件中\(successCount)件を取り込んだよ（\(failureCount)件は失敗）"
        }
    }
}
