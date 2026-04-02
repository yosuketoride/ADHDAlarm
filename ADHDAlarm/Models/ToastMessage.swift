import Foundation

/// Toast通知のメッセージモデル
struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let style: ToastStyle
}

/// Toastの表示スタイル
enum ToastStyle {
    /// 画面下部・3秒・ふくろうメッセージ（🦉自動付与）
    case owlTip
    /// 画面上部・3秒・エラー（赤背景）
    case error
    /// 画面下部・2秒・成功（緑背景）
    case success
}
