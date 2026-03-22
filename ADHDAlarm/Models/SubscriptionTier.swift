import Foundation

/// サブスクリプション階層と機能ゲートの定義
enum SubscriptionTier: String, Codable {
    case free
    case pro

    // MARK: - 機能ゲート

    /// 事前通知の最大設定回数
    var maxPreNotifications: Int {
        switch self {
        case .free: return 1
        case .pro:  return 3
        }
    }

    /// カレンダーを自由に選択できるか（falseの場合はデフォルトのみ）
    var canSelectCalendar: Bool {
        self == .pro
    }

    /// 解放済みテーマ数（無料版はB&W + Liquid Glass 1種のみ）
    var unlockedThemeCount: Int {
        switch self {
        case .free: return 2   // B&W + Liquid Glass お試し1種
        case .pro:  return 99  // 全テーマ
        }
    }

    /// 音声キャラクターを選択できるか
    var canSelectVoiceCharacter: Bool {
        self == .pro
    }
}
