import Foundation

/// マイク入力の操作モード
enum MicInputMode: String, CaseIterable, Codable {
    case pressAndHold = "press_and_hold"  // 押しながら話す（従来方式）
    case tapToggle    = "tap_toggle"      // タップで開始→タップで終了（高齢者対応）

    var displayName: String {
        switch self {
        case .pressAndHold: return "押しながら話す"
        case .tapToggle:    return "タップで開始・終了"
        }
    }
}
