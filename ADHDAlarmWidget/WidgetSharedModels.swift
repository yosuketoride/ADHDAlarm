import Foundation

// メインアプリのAlarmEvent/VoiceCharacterをWidgetターゲット内で再宣言
// JSON形式が一致している必要がある（AlarmEvent.swiftと同じCodable構造）

/// AlarmEventのVoiceCharacterと同じraw valueを使う（JSONの互換性が必須）
enum WidgetVoiceCharacter: String, Codable {
    case femaleConcierge  = "female_concierge"
    case maleButler       = "male_butler"
    case customRecording  = "custom_recording"
}

enum WidgetCompletionStatus: String, Codable {
    case completed
    case skipped
    case awaitingResponse  // 通知済みだがユーザーがまだ操作していない（反応待ち）
}

struct WidgetAlarmEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var fireDate: Date
    var preNotificationMinutes: Int
    var eventKitIdentifier: String?
    var alarmKitIdentifier: UUID?
    var voiceFileName: String?
    var calendarIdentifier: String?
    var voiceCharacter: WidgetVoiceCharacter
    let createdAt: Date
    var eventEmoji: String?
    var completionStatus: WidgetCompletionStatus?
}
