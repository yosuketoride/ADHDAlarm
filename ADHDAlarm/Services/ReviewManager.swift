import StoreKit
import UIKit

/// レビュー依頼の「神タイミング」管理
///
/// 「とめる」ボタンを押して予定が完了した直後にのみリクエストを発火する。
/// ・完了5回目・15回目・30回目、以降は30回ごと
/// ・SOS発信時（パニック中）は絶対に発火しない
/// ・前回から30日以上経過していない場合は発火しない
final class ReviewManager {

    static let shared = ReviewManager()
    private init() {}

    // MARK: - UserDefaultsキー

    private let countKey    = "review_completedAlarmCount"
    private let dateKey     = "review_lastRequestDate"

    // MARK: - 公開API

    /// 予定完了時に呼び出す。条件を満たした場合にレビューダイアログを表示する。
    /// - Parameter isSOSFired: SOSが発動していた場合は true（パニック中はリクエストしない）
    func recordCompletionAndRequestIfNeeded(isSOSFired: Bool) {
        // SOS発動中はリクエストしない（不満状態のユーザーを排除）
        guard !isSOSFired else { return }

        // 完了カウントをインクリメント
        var count = UserDefaults.standard.integer(forKey: countKey)
        count += 1
        UserDefaults.standard.set(count, forKey: countKey)

        // 対象回数かチェック（5回目・15回目・30回目、以降は30の倍数）
        let milestones = [5, 15, 30]
        let isMilestone = milestones.contains(count) || (count > 30 && count % 30 == 0)
        guard isMilestone else { return }

        // 前回リクエストから30日以上経過しているかチェック
        let lastDate = UserDefaults.standard.object(forKey: dateKey) as? Date ?? .distantPast
        let thirtyDays: TimeInterval = 60 * 60 * 24 * 30
        guard Date().timeIntervalSince(lastDate) > thirtyDays else { return }

        // フォアグラウンドシーンを取得してリクエスト発火
        DispatchQueue.main.async { [self] in
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }

            AppStore.requestReview(in: scene)
            UserDefaults.standard.set(Date(), forKey: dateKey)
        }
    }
}
