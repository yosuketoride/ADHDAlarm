import SwiftUI

/// オンボーディング: ふくろうとの出会い
struct PersonWelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var wingFlap = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("owl_stage0_normal")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(wingFlap ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: wingFlap
                )
                .onAppear { wingFlap = true }

            Spacer().frame(height: Spacing.xl)

            VStack(spacing: Spacing.sm) {
                Text("忘れても大丈夫。")
                    .font(.title2.bold())
                Text("ふくろうが代わりに")
                    .font(.title2.bold())
                Text("覚えておきます。")
                    .font(.title2.bold())
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.md)

            Spacer()

            Button("🦉 はじめる") {
                appState.onboardingPath.append(OnboardingDestination.permissionsCTA)
            }
            .frame(maxWidth: .infinity)
            .frame(height: ComponentSize.primary)
            .background(Color.owlAmber)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .navigationBarBackButtonHidden()
    }
}
