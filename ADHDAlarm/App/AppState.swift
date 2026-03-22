import Foundation
import Observation

/// アプリ全体のグローバル状態
/// @Observableにより、依存するViewが自動的に再描画される
@Observable
final class AppState {
    // MARK: - オンボーディング
    var isOnboardingComplete: Bool {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: Constants.Keys.onboardingComplete) }
    }

    // MARK: - サブスクリプション
    var subscriptionTier: SubscriptionTier {
        didSet {
            UserDefaults.standard.set(subscriptionTier.rawValue, forKey: Constants.Keys.subscriptionTier)
            // Siriのプロセス（App Extension）からも読めるようApp Groupにも書く
            UserDefaults(suiteName: Constants.appGroupID)?.set(subscriptionTier.rawValue, forKey: Constants.Keys.subscriptionTier)
        }
    }

    // MARK: - 設定
    var voiceCharacter: VoiceCharacter {
        didSet {
            UserDefaults.standard.set(voiceCharacter.rawValue, forKey: Constants.Keys.voiceCharacter)
            UserDefaults(suiteName: Constants.appGroupID)?.set(voiceCharacter.rawValue, forKey: Constants.Keys.voiceCharacter)
        }
    }

    var preNotificationMinutes: Int {
        didSet {
            UserDefaults.standard.set(preNotificationMinutes, forKey: Constants.Keys.preNotificationMinutes)
            UserDefaults(suiteName: Constants.appGroupID)?.set(preNotificationMinutes, forKey: Constants.Keys.preNotificationMinutes)
        }
    }

    var selectedCalendarID: String? {
        didSet {
            UserDefaults.standard.set(selectedCalendarID, forKey: Constants.Keys.selectedCalendarID)
            UserDefaults(suiteName: Constants.appGroupID)?.set(selectedCalendarID, forKey: Constants.Keys.selectedCalendarID)
        }
    }

    // MARK: - 表示モード
    /// 高齢者モード: 文字を大きく・色を高コントラストに（PRO機能）
    var isAccessibilityModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isAccessibilityModeEnabled, forKey: Constants.Keys.accessibilityModeEnabled) }
    }

    // MARK: - アラーム動作
    var notificationType: NotificationType {
        didSet { UserDefaults.standard.set(notificationType.rawValue, forKey: Constants.Keys.notificationType) }
    }

    var audioOutputMode: AudioOutputMode {
        didSet { UserDefaults.standard.set(audioOutputMode.rawValue, forKey: Constants.Keys.audioOutputMode) }
    }

    /// マイク入力モード（タップで開始/終了 or 押しながら話す）
    var micInputMode: MicInputMode {
        didSet { UserDefaults.standard.set(micInputMode.rawValue, forKey: Constants.Keys.micInputMode) }
    }

    // MARK: - 見守り（PRO）
    /// エスカレーション通知の送信先電話番号（家族など）
    var sosContactPhone: String? {
        didSet { UserDefaults.standard.set(sosContactPhone, forKey: Constants.Keys.sosContactPhone) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.isOnboardingComplete = defaults.bool(forKey: Constants.Keys.onboardingComplete)
        self.subscriptionTier = SubscriptionTier(rawValue: defaults.string(forKey: Constants.Keys.subscriptionTier) ?? "") ?? .free
        self.voiceCharacter = VoiceCharacter(rawValue: defaults.string(forKey: Constants.Keys.voiceCharacter) ?? "") ?? .femaleConcierge
        self.preNotificationMinutes = defaults.integer(forKey: Constants.Keys.preNotificationMinutes) == 0
            ? 15
            : defaults.integer(forKey: Constants.Keys.preNotificationMinutes)
        self.selectedCalendarID = defaults.string(forKey: Constants.Keys.selectedCalendarID)
        self.isAccessibilityModeEnabled = defaults.bool(forKey: Constants.Keys.accessibilityModeEnabled)
        self.notificationType = NotificationType(
            rawValue: defaults.string(forKey: Constants.Keys.notificationType) ?? ""
        ) ?? .alarmAndVoice
        self.audioOutputMode = AudioOutputMode(
            rawValue: defaults.string(forKey: Constants.Keys.audioOutputMode) ?? ""
        ) ?? .automatic
        self.micInputMode = MicInputMode(
            rawValue: defaults.string(forKey: Constants.Keys.micInputMode) ?? ""
        ) ?? .tapToggle
        self.sosContactPhone = defaults.string(forKey: Constants.Keys.sosContactPhone)
    }
}
