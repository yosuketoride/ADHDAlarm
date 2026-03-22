import SwiftUI

extension Color {
    // MARK: - デフォルトテーマ（白黒・高コントラスト）
    static let themeBackground  = Color(.systemBackground)
    static let themePrimary     = Color(.label)
    static let themeSecondary   = Color(.secondaryLabel)
    static let themeAccent      = Color.blue

    // MARK: - アラームカラー
    static let alarmRed         = Color.red
    static let snoozeBlue       = Color.blue
    static let warningYellow    = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let safeGreen        = Color.green
}
