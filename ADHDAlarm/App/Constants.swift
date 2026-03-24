import Foundation

enum Constants {
    // MARK: - UserDefaultsキー
    enum Keys {
        static let onboardingComplete    = "onboarding_complete"
        static let subscriptionTier      = "subscription_tier"
        static let voiceCharacter        = "voice_character"
        static let preNotificationMinutes = "pre_notification_minutes"
        static let preNotificationMinutesList = "pre_notification_minutes_list"
        static let selectedCalendarID    = "selected_calendar_id"
        static let accessibilityModeEnabled = "accessibility_mode_enabled"
        static let alarmEventMappings    = "alarm_event_mappings"
        static let notificationType      = "notification_type"
        static let audioOutputMode       = "audio_output_mode"
        static let micInputMode          = "mic_input_mode"
        static let sosContactPhone        = "sos_contact_phone"
        static let sosEscalationMinutes  = "sos_escalation_minutes"
        static let sosPairingId          = "sos_pairing_id"
    }

    // MARK: - Supabase (SOS LINE連携用)
    enum Supabase {
        // TODO: 実際のSupabaseプロジェクトURLとAnon Keyに置き換えること
        static let projectURL = "https://frvrvuwuottwphzkvxss.supabase.co"
        static let anonKey    = "sb_publishable_So0dQ0oVEycAnA4gzYaP1A_FXghS77I"
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

    // MARK: - 法的URL（App Store審査必須。提出前に実際のURLに差し替えること）
    enum LegalURL {
        /// 利用規約ページのURL
        static let terms   = "https://yosuketoride.github.io/koememo/terms"
        /// プライバシーポリシーページのURL
        static let privacy = "https://yosuketoride.github.io/koememo/privacy"
    }

    // MARK: - StoreKit
    enum ProductID {
        static let proMonthly  = "com.yosuke.ADHDAlarm.pro.monthly"
        static let proYearly   = "com.yosuke.ADHDAlarm.pro.yearly"
        static let proLifetime = "com.yosuke.ADHDAlarm.pro.lifetime"
    }

}
