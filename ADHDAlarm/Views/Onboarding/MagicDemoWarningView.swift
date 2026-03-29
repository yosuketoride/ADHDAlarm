import SwiftUI

/// オンボーディング: 音が出ます警告（MagicDemo直前）
struct MagicDemoWarningView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: IconSize.xl))
                .foregroundStyle(Color.owlAmber)

            Spacer().frame(height: Spacing.xl)

            VStack(spacing: Spacing.sm) {
                Text("これから音が鳴ります")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("今、周りに人がいますか？\nイヤホンを使うか、\n音量を確認してから\nボタンを押してください")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            VStack(spacing: Spacing.md) {
                Button("🔔 鳴らしてみる！") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    appState.onboardingPath.append(OnboardingDestination.magicDemo(hapticOnly: false))
                }
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.primary)
                .background(Color.owlAmber)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

                Button("音を出さずにスキップ →") {
                    appState.onboardingPath.append(OnboardingDestination.magicDemo(hapticOnly: true))
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: ComponentSize.small)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .navigationBarBackButtonHidden()
    }
}
