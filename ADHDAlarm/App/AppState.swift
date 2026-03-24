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

    /// デフォルトの事前通知タイミング（複数選択対応）
    var preNotificationMinutesList: Set<Int> {
        didSet {
            let arr = Array(preNotificationMinutesList)
            UserDefaults.standard.set(arr, forKey: Constants.Keys.preNotificationMinutesList)
            UserDefaults(suiteName: Constants.appGroupID)?.set(arr, forKey: Constants.Keys.preNotificationMinutesList)
        }
    }

    /// 後方互換プロパティ: 単一値が必要な箇所では最大値を使用
    var preNotificationMinutes: Int {
        preNotificationMinutesList.max() ?? 15
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
    /// Supabase LINEペアリング用のID (UUID文字列表現)
    var sosPairingId: String? {
        didSet { UserDefaults.standard.set(sosPairingId, forKey: Constants.Keys.sosPairingId) }
    }
    /// アラーム停止されなかった場合にSOSを送るまでの時間（分）
    var sosEscalationMinutes: Int {
        didSet { UserDefaults.standard.set(sosEscalationMinutes, forKey: Constants.Keys.sosEscalationMinutes) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.isOnboardingComplete = defaults.bool(forKey: Constants.Keys.onboardingComplete)
        self.subscriptionTier = SubscriptionTier(rawValue: defaults.string(forKey: Constants.Keys.subscriptionTier) ?? "") ?? .free
        self.voiceCharacter = VoiceCharacter(rawValue: defaults.string(forKey: Constants.Keys.voiceCharacter) ?? "") ?? .femaleConcierge
        // 新形式（Set<Int>）を優先し、なければ旧形式（Int）から移行
        if let arr = defaults.array(forKey: Constants.Keys.preNotificationMinutesList) as? [Int], !arr.isEmpty {
            self.preNotificationMinutesList = Set(arr)
        } else {
            let legacy = defaults.integer(forKey: Constants.Keys.preNotificationMinutes)
            self.preNotificationMinutesList = [legacy == 0 ? 15 : legacy]
        }
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
        self.sosPairingId = defaults.string(forKey: Constants.Keys.sosPairingId)
        let storedEscalation = defaults.integer(forKey: Constants.Keys.sosEscalationMinutes)
        self.sosEscalationMinutes = storedEscalation == 0 ? 5 : storedEscalation
    }
}
