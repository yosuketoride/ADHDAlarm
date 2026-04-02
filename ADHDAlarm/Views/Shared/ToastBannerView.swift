import SwiftUI

/// UIWindowレベルで表示されるToastバナー
/// ToastWindowManager から UIHostingController 経由で使用する
struct ToastBannerView: View {
    let message: ToastMessage
    @State private var appeared = false

    var body: some View {
        VStack {
            if message.style == .error {
                // エラー: 上から降りてくる
                toastContent
                    .padding(.top, 60)
                Spacer()
            } else {
                // owlTip / success: 下から上がってくる（FABの上）
                Spacer()
                toastContent
                    .padding(.bottom, ComponentSize.fab + Spacing.lg)
            }
        }
        .padding(.horizontal, Spacing.md)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var toastContent: some View {
        switch message.style {
        case .owlTip:
            Text("🦉 \(message.text)")
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))

        case .error:
            Text(message.text)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(Color.statusDanger)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .transition(.move(edge: .top).combined(with: .opacity))

        case .success:
            Text(message.text)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.statusSuccess)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
