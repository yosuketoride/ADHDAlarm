import Foundation
import Observation
import SwiftUI
import WidgetKit

/// アプリ全体のグローバル状態
/// @Observableにより、依存するViewが自動的に再描画される
@Observable @MainActor
final class AppState {
    // MARK: - モード選択
    var appMode: AppMode? {
        didSet {
            UserDefaults.standard.set(appMode?.rawValue, forKey: Constants.Keys.appMode)
        }
    }

    // MARK: - フクロウキャラクター
    var owlName: String {
        didSet {
            UserDefaults.standard.set(owlName, forKey: Constants.Keys.owlName)
            UserDefaults(suiteName: Constants.appGroupID)?.set(owlName, forKey: Constants.Keys.owlName)
        }
    }
    var owlXP: Int {
        didSet {
            UserDefaults.standard.set(owlXP, forKey: Constants.Keys.owlXP)
            UserDefaults(suiteName: Constants.appGroupID)?.set(owlXP, forKey: Constants.Keys.owlXP)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    var owlStage: Int {
        didSet {
            UserDefaults.standard.set(owlStage, forKey: Constants.Keys.owlStage)
            UserDefaults(suiteName: Constants.appGroupID)?.set(owlStage, forKey: Constants.Keys.owlStage)
        }
    }

    // MARK: - ナビゲーション
    var personNavigationPath = NavigationPath()
    var familyNavigationPath = NavigationPath()
    /// シートをすべて閉じるためのトリガー
    var dismissAllSheets = false
    /// オンボーディング NavigationStack のパス（起動間で保持不要）
    var onboardingPath = NavigationPath()
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

    /// クリアボイスモード: ONにするとゆっくり・低い声で読み上げる（聞き取りやすさ優先）
    var isClearVoiceEnabled: Bool {
        didSet { UserDefaults.standard.set(isClearVoiceEnabled, forKey: Constants.Keys.isClearVoiceEnabled) }
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
    /// Supabase LINEペアリング用のID (UUID文字列表現)
    var sosPairingId: String? {
        didSet { UserDefaults.standard.set(sosPairingId, forKey: Constants.Keys.sosPairingId) }
    }
    /// アラーム停止されなかった場合にSOSを送るまでの時間（分）
    var sosEscalationMinutes: Int {
        didSet { UserDefaults.standard.set(sosEscalationMinutes, forKey: Constants.Keys.sosEscalationMinutes) }
    }

    // MARK: - XP管理

    /// XPを加算する（1日の上限50XP。日付をまたいだ場合は今日のXPをリセット）
    func addXP(_ amount: Int) {
        let cap = 50
        let defaults = UserDefaults.standard
        // 日付が変わっていたら今日のXPをリセット
        let lastDate = defaults.object(forKey: Constants.Keys.owlXPLastDate) as? Date ?? .distantPast
        var dailyAdded = defaults.integer(forKey: Constants.Keys.owlXPToday)
        if !Calendar.current.isDateInToday(lastDate) {
            dailyAdded = 0
            defaults.set(0, forKey: Constants.Keys.owlXPToday)
        }
        let actual = min(amount, cap - dailyAdded)
        guard actual > 0 else { return }
        owlXP += actual
        defaults.set(dailyAdded + actual, forKey: Constants.Keys.owlXPToday)
        defaults.set(Date(), forKey: Constants.Keys.owlXPLastDate)
    }

    // MARK: - グローバルトースト
    /// アプリ全体で表示するトーストメッセージ（nilで非表示）
    var globalToast: String?

    // MARK: - 家族リモートスケジュール（PRO）
    /// 自分が親としてペアリングしているリンクID（子から予定を受け取る側）
    var familyLinkId: String? {
        didSet { UserDefaults.standard.set(familyLinkId, forKey: Constants.Keys.familyLinkId) }
    }
    /// 自分が子としてペアリングしているリンクIDの一覧（親に予定を送る側、複数対応）
    var familyChildLinkIds: [String] {
        didSet { UserDefaults.standard.set(familyChildLinkIds, forKey: Constants.Keys.familyChildLinkIds) }
    }
    /// 未読の家族予定件数（ダッシュボードのバナー表示用）
    var unreadFamilyEventCount: Int {
        didSet { UserDefaults.standard.set(unreadFamilyEventCount, forKey: Constants.Keys.unreadFamilyEventCount) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.appMode = AppMode(rawValue: defaults.string(forKey: Constants.Keys.appMode) ?? "")
        self.owlName = defaults.string(forKey: Constants.Keys.owlName) ?? "ふくろう"
        self.owlXP = defaults.integer(forKey: Constants.Keys.owlXP)
        self.owlStage = defaults.integer(forKey: Constants.Keys.owlStage)
        self.isOnboardingComplete = defaults.bool(forKey: Constants.Keys.onboardingComplete)
        self.subscriptionTier = SubscriptionTier(rawValue: defaults.string(forKey: Constants.Keys.subscriptionTier) ?? "") ?? .free
        self.voiceCharacter = VoiceCharacter(rawValue: defaults.string(forKey: Constants.Keys.voiceCharacter) ?? "") ?? .femaleConcierge
        self.isClearVoiceEnabled = defaults.bool(forKey: Constants.Keys.isClearVoiceEnabled)
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
        self.sosPairingId = defaults.string(forKey: Constants.Keys.sosPairingId)
        let storedEscalation = defaults.integer(forKey: Constants.Keys.sosEscalationMinutes)
        // 0 = デバッグビルド専用の10秒テストモード。未設定（UserDefaultsが返すデフォルト0）と区別するためキーの存在確認が必要
        self.sosEscalationMinutes = defaults.object(forKey: Constants.Keys.sosEscalationMinutes) == nil ? 5 : storedEscalation
        self.familyLinkId = defaults.string(forKey: Constants.Keys.familyLinkId)
        self.familyChildLinkIds = defaults.stringArray(forKey: Constants.Keys.familyChildLinkIds) ?? []
        self.unreadFamilyEventCount = defaults.integer(forKey: Constants.Keys.unreadFamilyEventCount)

        // didSet は init 内では呼ばれないため、App Group に現在の XP を手動で同期する
        // これによりウィジェットが常に最新のステージを表示できる
        let appGroup = UserDefaults(suiteName: Constants.appGroupID)
        appGroup?.set(self.owlXP, forKey: Constants.Keys.owlXP)
        appGroup?.set(self.owlName, forKey: Constants.Keys.owlName)
    }
}
