import Foundation

// メインアプリのAlarmEvent/VoiceCharacterをWidgetターゲット内で再宣言
// JSON形式が一致している必要がある（AlarmEvent.swiftと同じCodable構造）

enum WidgetVoiceCharacter: String, Codable {
    case femaleConcierge
    case maleButler
    case customRecording
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
}
