import SwiftUI

extension Color {
    // MARK: - ブランドカラー
    static let owlAmber     = Color(hex: "#F5A623")
    static let owlAmberDark = Color(hex: "#F7B544")  // ダークモード専用
    static let owlBrown     = Color(hex: "#8B5E3C")
    static let owlBrownDark = Color(hex: "#A87850")  // ダークモード専用

    // MARK: - ステータスカラー
    static let statusSuccess = Color(hex: "#34C759")
    static let statusWarning = Color(hex: "#FF9500")
    static let statusDanger  = Color(hex: "#FF3B30")
    static let statusPending = Color(hex: "#007AFF")
    static let statusSkipped = Color(hex: "#8E8E93")

    // MARK: - XP
    static let xpGold = Color(hex: "#FFD700")

    // MARK: - 時間帯カラー（背景に .opacity を重ねて使う）
    static let morning   = Color(hex: "#87CEEB")  // 朝
    static let afternoon = Color(hex: "#FFF9C4")  // 昼
    static let evening   = Color(hex: "#FFB347")  // 夕
    static let night     = Color(hex: "#4B5EA3")  // 夜

    // MARK: - 16進数ヘルパー
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255
        )
    }
}
