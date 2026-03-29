import Foundation

/// アプリの使用モード（初回起動時に1回だけ選択・設定から変更可能）
enum AppMode: String, Codable {
    /// 当事者（ADHD・高齢者本人）― タブなし1画面のシンプルUI
    case person
    /// 家族（見守る側・代理入力する側）― 3タブの管理UI
    case family
}
