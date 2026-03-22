import Foundation

/// アラーム発火時の通知方式
enum NotificationType: String, CaseIterable, Codable {
    /// AlarmKitのアラーム音のみ（音声ナレーションなし）
    case alarmOnly = "alarm_only"
    /// アラーム音 + 音声ナレーション（デフォルト）
    case alarmAndVoice = "alarm_and_voice"

    var displayName: String {
        switch self {
        case .alarmOnly:    return "アラームのみ"
        case .alarmAndVoice: return "アラーム＋音声"
        }
    }

    var description: String {
        switch self {
        case .alarmOnly:    return "AlarmKitの音のみ鳴らします"
        case .alarmAndVoice: return "予定名を音声でお知らせします"
        }
    }
}
