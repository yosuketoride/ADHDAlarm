import Foundation

// MARK: - 完了状態

/// アラームの完了状態
/// nil = まだ発火していない or 未対応（後方互換）
enum CompletionStatus: String, Codable {
    case completed  // ユーザーが「とめる」を押した
    case skipped    // ユーザーが「スキップ」を選んだ
    case missed     // P-5-1: 15分以上遅延して届いたリモート予定（AlarmKit未登録のまま保存）
}

/// アプリのコアドメインモデル。
/// EventKit (eventKitIdentifier) と AlarmKit (alarmKitIdentifier) の橋渡し役。
/// App Groupコンテナに永続化され、ウィジェットとも共有される。
struct AlarmEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var fireDate: Date
    /// アラーム何分前に事前通知するか（デフォルト: 15分）
    var preNotificationMinutes: Int
    /// EventKitのEKEvent.eventIdentifier
    var eventKitIdentifier: String?
    /// AlarmKitのアラームID（後方互換。新規は alarmKitIdentifiers を使用）
    var alarmKitIdentifier: UUID?
    /// 複数の事前通知アラームID（複数選択時に複数登録）
    var alarmKitIdentifiers: [UUID]
    /// AlarmKit ID → 事前通知分数のマッピング（発火時に正しい分数を特定するために使用）
    /// キーは UUID.uuidString（JSONのキーは文字列型のみサポートのため）
    var alarmKitMinutesMap: [String: Int]
    /// Library/Sounds内の.cafファイル相対パス（ファイル名のみ）
    var voiceFileName: String?
    /// 書き込み先カレンダーのID（nilの場合はデフォルトカレンダー）
    var calendarIdentifier: String?
    /// 音声キャラクター
    var voiceCharacter: VoiceCharacter
    let createdAt: Date
    /// 繰り返しルール（nilなら単発予定）
    var recurrenceRule: RecurrenceRule?
    /// 繰り返し予定のグループID（同じ繰り返しグループのアラームが共有するID）
    var recurrenceGroupID: UUID?
    /// 家族リモートスケジュールで作成された場合のremote_events.id（ロールバック検索用）
    var remoteEventId: String?
    /// NLParserが推定した絵文字アイコン（nil → 表示時は "📌" をフォールバック）
    var eventEmoji: String?
    /// アラームへの対応状態（nil = 未対応 or 過去日時プロキシで判定）
    var completionStatus: CompletionStatus?
    /// スヌーズを押した回数（最大3回でボタン非表示、P-2-2/P-9-15）
    var snoozeCount: Int
    /// 時間指定なし（ToDo）タスクかどうか（P-1-11）
    /// trueの場合アラーム発火なし・ホーム最上部に常駐
    var isToDo: Bool
    /// Undo操作後の上書き保護期限（P-9-1）
    /// この時刻までは家族側からのcomplete上書きをブロックする
    var undoPendingUntil: Date?

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        fireDate: Date,
        preNotificationMinutes: Int = 15,
        eventKitIdentifier: String? = nil,
        alarmKitIdentifier: UUID? = nil,
        alarmKitIdentifiers: [UUID] = [],
        alarmKitMinutesMap: [String: Int] = [:],
        voiceFileName: String? = nil,
        calendarIdentifier: String? = nil,
        voiceCharacter: VoiceCharacter = .femaleConcierge,
        createdAt: Date = Date(),
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceGroupID: UUID? = nil,
        remoteEventId: String? = nil,
        eventEmoji: String? = nil,
        completionStatus: CompletionStatus? = nil,
        snoozeCount: Int = 0,
        isToDo: Bool = false,
        undoPendingUntil: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.fireDate = fireDate
        self.preNotificationMinutes = preNotificationMinutes
        self.eventKitIdentifier = eventKitIdentifier
        self.alarmKitIdentifier = alarmKitIdentifier
        self.alarmKitIdentifiers = alarmKitIdentifiers
        self.alarmKitMinutesMap = alarmKitMinutesMap
        self.voiceFileName = voiceFileName
        self.calendarIdentifier = calendarIdentifier
        self.voiceCharacter = voiceCharacter
        self.createdAt = createdAt
        self.recurrenceRule = recurrenceRule
        self.recurrenceGroupID = recurrenceGroupID
        self.remoteEventId = remoteEventId
        self.eventEmoji = eventEmoji
        self.completionStatus = completionStatus
        self.snoozeCount = snoozeCount
        self.isToDo = isToDo
        self.undoPendingUntil = undoPendingUntil
    }

    // MARK: - Codable（後方互換）
    // 新しいフィールド（alarmKitIdentifiers等）が欠けていても古いJSONを読める

    enum CodingKeys: String, CodingKey {
        case id, title, fireDate, preNotificationMinutes
        case eventKitIdentifier, alarmKitIdentifier
        case alarmKitIdentifiers, alarmKitMinutesMap
        case voiceFileName, calendarIdentifier, voiceCharacter
        case createdAt, recurrenceRule, recurrenceGroupID, remoteEventId
        case eventEmoji
        case completionStatus
        case snoozeCount
        case isToDo
        case undoPendingUntil
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                     = try c.decode(UUID.self,   forKey: .id)
        title                  = try c.decode(String.self, forKey: .title)
        fireDate               = try c.decode(Date.self,   forKey: .fireDate)
        preNotificationMinutes = try c.decodeIfPresent(Int.self,          forKey: .preNotificationMinutes) ?? 15
        eventKitIdentifier     = try c.decodeIfPresent(String.self,       forKey: .eventKitIdentifier)
        alarmKitIdentifier     = try c.decodeIfPresent(UUID.self,         forKey: .alarmKitIdentifier)
        alarmKitIdentifiers    = try c.decodeIfPresent([UUID].self,       forKey: .alarmKitIdentifiers)    ?? []
        alarmKitMinutesMap     = try c.decodeIfPresent([String: Int].self, forKey: .alarmKitMinutesMap)   ?? [:]
        voiceFileName          = try c.decodeIfPresent(String.self,       forKey: .voiceFileName)
        calendarIdentifier     = try c.decodeIfPresent(String.self,       forKey: .calendarIdentifier)
        voiceCharacter         = try c.decodeIfPresent(VoiceCharacter.self, forKey: .voiceCharacter)      ?? .femaleConcierge
        createdAt              = try c.decodeIfPresent(Date.self,         forKey: .createdAt)              ?? Date()
        recurrenceRule         = try c.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule)
        recurrenceGroupID      = try c.decodeIfPresent(UUID.self,         forKey: .recurrenceGroupID)
        remoteEventId          = try c.decodeIfPresent(String.self,            forKey: .remoteEventId)
        eventEmoji             = try c.decodeIfPresent(String.self,            forKey: .eventEmoji)
        completionStatus       = try c.decodeIfPresent(CompletionStatus.self,  forKey: .completionStatus)
        snoozeCount            = try c.decodeIfPresent(Int.self,                forKey: .snoozeCount) ?? 0
        isToDo                 = try c.decodeIfPresent(Bool.self,               forKey: .isToDo) ?? false
        undoPendingUntil       = try c.decodeIfPresent(Date.self,               forKey: .undoPendingUntil)
    }

    // encode(to:) を明示実装。init(from:) をカスタム定義した場合、将来のプロパティ追加時に
    // エンコード側だけ漏れるサイレントバグを防ぐためセットで定義する（レビュー指摘 #4）
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                     forKey: .id)
        try c.encode(title,                  forKey: .title)
        try c.encode(fireDate,               forKey: .fireDate)
        try c.encode(preNotificationMinutes, forKey: .preNotificationMinutes)
        try c.encodeIfPresent(eventKitIdentifier,  forKey: .eventKitIdentifier)
        try c.encodeIfPresent(alarmKitIdentifier,  forKey: .alarmKitIdentifier)
        try c.encode(alarmKitIdentifiers,          forKey: .alarmKitIdentifiers)
        try c.encode(alarmKitMinutesMap,            forKey: .alarmKitMinutesMap)
        try c.encodeIfPresent(voiceFileName,        forKey: .voiceFileName)
        try c.encodeIfPresent(calendarIdentifier,   forKey: .calendarIdentifier)
        try c.encode(voiceCharacter,                forKey: .voiceCharacter)
        try c.encode(createdAt,                     forKey: .createdAt)
        try c.encodeIfPresent(recurrenceRule,        forKey: .recurrenceRule)
        try c.encodeIfPresent(recurrenceGroupID,     forKey: .recurrenceGroupID)
        try c.encodeIfPresent(remoteEventId,         forKey: .remoteEventId)
        try c.encodeIfPresent(eventEmoji,            forKey: .eventEmoji)
        try c.encodeIfPresent(completionStatus,      forKey: .completionStatus)
        try c.encode(snoozeCount,                    forKey: .snoozeCount)
        try c.encode(isToDo,                         forKey: .isToDo)
        try c.encodeIfPresent(undoPendingUntil,      forKey: .undoPendingUntil)
    }

    /// 表示用タイトル。先頭に絵文字が付いている場合は先頭1個ぶんを取り除く
    nonisolated var displayTitle: String {
        var trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if let eventEmoji, !eventEmoji.isEmpty, trimmed.hasPrefix(eventEmoji) {
            trimmed.removeFirst(eventEmoji.count)
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? title : trimmed
        }

        if let firstScalar = trimmed.unicodeScalars.first,
           firstScalar.properties.isEmojiPresentation || firstScalar.properties.isEmoji {
            trimmed.removeFirst()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed.isEmpty ? title : trimmed
    }
}
