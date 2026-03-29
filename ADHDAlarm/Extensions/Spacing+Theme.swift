import CoreGraphics

// MARK: - スペーシング（4pt grid）

enum Spacing {
    static let xs: CGFloat =  4
    static let sm: CGFloat =  8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - コンポーネントサイズ

enum ComponentSize {
    static let eventRow:      CGFloat = 64   // EventRow 最小高さ（高齢者の指が収まる最低ライン）
    static let fab:           CGFloat = 72   // マイクFAB（正方形）
    static let templateCard:  CGFloat = 80   // 家族送信テンプレートカード高さ
    static let settingRow:    CGFloat = 52   // 設定行の高さ
    static let inputField:    CGFloat = 52   // テキスト入力フィールドの高さ
    static let small:         CGFloat = 44   // Apple HIG 最小タップターゲット
    static let primary:       CGFloat = 56   // プライマリボタン（全画面共通）
    static let actionGiant:   CGFloat = 72   // RingingView 完了ボタン専用（primary と混同禁止）
    static let toggleChip:    CGFloat = 36   // トグルチップス（事前通知プリセット等）
}

// MARK: - コーナー半径

enum CornerRadius {
    static let sm:    CGFloat =  8
    static let md:    CGFloat = 12
    static let lg:    CGFloat = 16
    static let input: CGFloat = 10
    static let fab:   CGFloat = 36
    static let pill:  CGFloat = .infinity
}

// MARK: - ボーダー幅

enum BorderWidth {
    static let thin:  CGFloat = 1
    static let thick: CGFloat = 2
}

// MARK: - アイコンサイズ

enum IconSize {
    static let sm: CGFloat = 20   // 小アイコン・インラインアイコン
    static let md: CGFloat = 24   // 通常アイコン
    static let lg: CGFloat = 28   // EventRow 絵文字・テンプレートカード
    static let xl: CGFloat = 56   // 権限プリプロンプト等の大アイコン
}
