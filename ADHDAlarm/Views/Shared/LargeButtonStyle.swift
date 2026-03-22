import SwiftUI

/// 高齢者・ADHD向け巨大ボタンスタイル
/// タップターゲット最低60pt、余白たっぷり
struct LargeButtonStyle: ButtonStyle {
    var backgroundColor: Color = .blue
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .minimumScaleFactor(0.5)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)
            .padding(.horizontal, 12)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LargeButtonStyle {
    static var large: LargeButtonStyle { LargeButtonStyle() }
    static func large(background: Color, foreground: Color = .white) -> LargeButtonStyle {
        LargeButtonStyle(backgroundColor: background, foregroundColor: foreground)
    }
}
