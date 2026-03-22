import Foundation

enum Constants {
    // MARK: - UserDefaultsキー
    enum Keys {
        static let onboardingComplete    = "onboarding_complete"
        static let subscriptionTier      = "subscription_tier"
        static let voiceCharacter        = "voice_character"
        static let preNotificationMinutes = "pre_notification_minutes"
        static let selectedCalendarID    = "selected_calendar_id"
        static let accessibilityModeEnabled = "accessibility_mode_enabled"
        static let alarmEventMappings    = "alarm_event_mappings"
        static let notificationType      = "notification_type"
        static let audioOutputMode       = "audio_output_mode"
        static let micInputMode          = "mic_input_mode"
        static let sosContactPhone       = "sos_contact_phone"
    }

    // MARK: - App Group
    /// WidgetKitとデータを共有するためのApp Group ID
    static let appGroupID = "group.com.yosuke.ADHDAlarm"

    // MARK: - 音声ファイル
    /// .cafファイルを格納するLibrary/Sounds内のサブディレクトリ名
    static let soundsDirectoryName = "WasurebuAlarms"

    // MARK: - EventKitマーカー
    /// アプリが作成したイベントを識別するためのHTMLコメントマーカー（notes欄に埋め込む）
    static let eventMarkerPrefix = "<!-- wasure-bou:"
    static let eventMarkerSuffix = " -->"

    static func eventMarker(for id: UUID) -> String {
        "\(eventMarkerPrefix)\(id.uuidString)\(eventMarkerSuffix)"
    }

    // MARK: - StoreKit
    enum ProductID {
        static let proMonthly  = "com.yosuke.ADHDAlarm.pro.monthly"
        static let proLifetime = "com.yosuke.ADHDAlarm.pro.lifetime"
    }

}
