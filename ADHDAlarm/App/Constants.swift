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
        static let sosEscalationMinutes  = "sos_escalation_minutes"
        static let sosPairingId          = "sos_pairing_id"
        // 家族リモートスケジュール
        static let familyLinkId           = "family_link_id"
        static let familyChildLinkIds     = "family_child_link_ids"
        static let unreadFamilyEventCount = "unread_family_event_count"
        static let familyFirstCompletedBannerShown = "family_first_completed_banner_shown"
        // モード選択
        static let appMode                = "app_mode"
        // フクロウキャラクター
        static let owlName                = "owl_name"
        static let owlXP                  = "owl_xp"
        static let owlStage               = "owl_stage"
        static let isClearVoiceEnabled    = "is_clear_voice_enabled"
        // XP 日次管理（日付をまたいだリセット用）
        static let owlXPToday             = "owl_xp_today"
        static let owlXPLastDate          = "owl_xp_last_date"
        // 通知のdismissで処理済みとみなしたAlarmKit ID
        static let handledAlarmKitIDs     = "handled_alarm_kit_ids"
    }

    // MARK: - Supabase (SOS LINE連携用)
    enum Supabase {
        // ⚠️ セキュリティ注意（レビュー指摘）:
        // Supabase Anon Key はクライアント公開前提のキーだが、ソースコードへの直書きは
        // リポジトリ公開時に Bot にスクレイピングされるリスクがある。
        // リリース前に Secrets.xcconfig（.gitignore 済み）へ移行すること。
        //   手順: Xcode > Project > Info > Configurations に xcconfig を追加し、
        //         SUPABASE_URL / SUPABASE_ANON_KEY をビルド変数として定義する。
        // ⚠️ Supabase ダッシュボードで全テーブルの RLS が有効になっていることも必ず確認。
        nonisolated static let projectURL = "https://frvrvuwuottwphzkvxss.supabase.co"
        nonisolated static let anonKey    = "sb_publishable_So0dQ0oVEycAnA4gzYaP1A_FXghS77I"
    }

    // MARK: - App Group
    /// WidgetKitとデータを共有するためのApp Group ID
    static let appGroupID = "group.com.yosuke.WasurenboAlarm"

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
        static let terms   = "https://yosuketoride.github.io/ADHDAlarm/terms"
        /// プライバシーポリシーページのURL
        static let privacy = "https://yosuketoride.github.io/ADHDAlarm/privacy"
        /// よくある質問ページ（NotionページのURL。確定後に設定）
        static let faqURL: URL? = nil
        /// お問い合わせメール（mailto:リンク）
        static var supportMailURL: URL? {
            let subject = "【ふくろう】お問い合わせ"
            guard let encoded = subject.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) else { return nil }
            return URL(string: "mailto:yosuketoride@gmail.com?subject=\(encoded)")
        }
        /// App Storeレビューページ（リリース後にApp Store IDを設定）
        static let appStoreReviewURL: URL? = nil
    }

    // MARK: - 通知アクション（バナーの「止める / あとで / 今日は休む」ボタン）
    enum Notification {
        /// アラームカテゴリID（UNNotificationCategory に登録する識別子）
        static let alarmCategoryID = "ALARM_CATEGORY"
        /// 「止める」アクションID
        static let actionDismiss   = "ALARM_DISMISS"
        /// 「あとで（30分後）」アクションID
        static let actionSnooze    = "ALARM_SNOOZE"
        /// 「今日は休む」アクションID
        static let actionSkip      = "ALARM_SKIP"
    }

    // MARK: - StoreKit
    enum ProductID {
        static let proMonthly  = "com.yosuke.WasurenboAlarm.monthly"
        static let proYearly   = "com.yosuke.WasurenboAlarm.Yearly"
        static let proLifetime = "com.yosuke.WasurenboAlarm.lifetime"
    }

}
