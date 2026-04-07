import Foundation

/// オフライン中に送れなかった家族同期アクションを一時保存する
///
/// v1では remote_events.status の更新だけを対象にする。
/// 同じ予定IDに対して複数操作があった場合は、最新操作のみを残す。
actor OfflineActionQueue {
    nonisolated static let shared = OfflineActionQueue()

    struct QueuedStatusAction: Codable, Equatable {
        let eventID: String
        let status: String
        let timestamp: Date
    }

    private let familyService: any FamilyScheduling
    private let defaults: UserDefaults
    private let storageKey = "offline_remote_status_queue"
    private let maxEntries = 100

    private var queuedActions: [QueuedStatusAction]
    private var isFlushing = false

    init(
        familyService: (any FamilyScheduling)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.familyService = familyService ?? FamilyRemoteService.shared
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([QueuedStatusAction].self, from: data) {
            self.queuedActions = decoded.sorted { $0.timestamp < $1.timestamp }
        } else {
            self.queuedActions = []
        }
    }

    /// まずは即時送信を試し、失敗した場合だけキューへ積む
    func sendOrEnqueueStatusUpdate(eventID: String, status: String) async {
        print("📤 [OfflineActionQueue/sendOrEnqueueStatusUpdate] 開始 eventID=\(eventID) status=\(status)")
        do {
            try await familyService.updateRemoteEventStatus(id: eventID, status: status)
            print("✅ [OfflineActionQueue/sendOrEnqueueStatusUpdate] 即時送信 成功 eventID=\(eventID) status=\(status)")
        } catch {
            print("⚠️ [OfflineActionQueue/sendOrEnqueueStatusUpdate] 即時送信 失敗→キュー積み eventID=\(eventID) status=\(status) error=\(error)")
            enqueueStatusUpdate(eventID: eventID, status: status, timestamp: Date())
        }
    }

    /// 同じ予定IDは最新操作だけを保持し、上限100件を超えたら最古から捨てる
    func enqueueStatusUpdate(eventID: String, status: String, timestamp: Date) {
        queuedActions.removeAll { $0.eventID == eventID }
        queuedActions.append(
            QueuedStatusAction(eventID: eventID, status: status, timestamp: timestamp)
        )
        queuedActions.sort { $0.timestamp < $1.timestamp }

        if queuedActions.count > maxEntries {
            queuedActions.removeFirst(queuedActions.count - maxEntries)
        }

        persist()
        debugLogQueueSize()
    }

    /// 溜まった順に1件ずつ送る。失敗したらそこで止める
    func flush() async {
        guard !isFlushing else { return }
        guard !queuedActions.isEmpty else { return }

        print("🔁 [OfflineActionQueue/flush] 開始 queue件数=\(queuedActions.count) 内容=\(queuedActions.map { "\($0.eventID):\($0.status)" })")
        isFlushing = true
        defer { isFlushing = false }

        while let action = queuedActions.first {
            do {
                try await familyService.updateRemoteEventStatus(id: action.eventID, status: action.status)
                queuedActions.removeFirst()
                persist()
                print("✅ [OfflineActionQueue/flush] 送信 成功 eventID=\(action.eventID) status=\(action.status) 残り=\(queuedActions.count)件")
                debugLogQueueSize()
            } catch {
                print("⚠️ [OfflineActionQueue/flush] 送信 失敗→中断 eventID=\(action.eventID) status=\(action.status) error=\(error)")
                break
            }
        }
    }

    func queuedCount() -> Int {
        queuedActions.count
    }

    func queuedSnapshot() -> [QueuedStatusAction] {
        queuedActions
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(queuedActions) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func debugLogQueueSize() {
        print("[OfflineActionQueue] queue size: \(queuedActions.count)")
    }
}
