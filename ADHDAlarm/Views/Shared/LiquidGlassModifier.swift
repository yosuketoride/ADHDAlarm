import SwiftUI

/// iOS 26 Liquid Glass 風のビジュアルエフェクト
/// isLiquidGlassEnabled = true の場合: 半透明マテリアル + ボーダー + シャドウ
/// false の場合: フラットな不透明背景
struct LiquidGlassModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        } else {
            content
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

extension View {
    func liquidGlass(enabled: Bool = true) -> some View {
        modifier(LiquidGlassModifier(isEnabled: enabled))
    }
}
