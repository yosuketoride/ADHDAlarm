import Foundation

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

    init(
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
        createdAt: Date = Date()
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
    }
}
