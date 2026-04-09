import SwiftUI

/// モード選択画面（初回起動時・設定変更時に表示）
struct ModeSelectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedMode: AppMode = .person

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("owl_stage0_normal")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)

            Spacer().frame(height: Spacing.lg)

            Text("どなたがお使いですか？")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Spacer().frame(height: Spacing.md)

            // 2カード横並び
            HStack(spacing: Spacing.md) {
                modeCard(
                    emoji: "👤",
                    title: "自分で使う",
                    mode: .person
                )
                modeCard(
                    emoji: "👨‍👩‍👧",
                    title: "家族の見守り",
                    mode: .family
                )
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            Button(appState.isOnboardingComplete ? "この設定で使う" : "🦉 はじめる") {
                confirmSelection()
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

    private func modeCard(emoji: String, title: String, mode: AppMode) -> some View {
        let isSelected = selectedMode == mode
        return Button {
            selectedMode = mode
        } label: {
            VStack(spacing: Spacing.sm) {
                Text(emoji)
                    .font(.system(size: IconSize.lg))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(isSelected ? Color.owlAmber : Color.clear, lineWidth: BorderWidth.thick)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func confirmSelection() {
        appState.appMode = selectedMode
        if appState.isOnboardingComplete {
            if selectedMode == .family {
                // 家族モードに切り替えるたびに WelcomeView を再表示する
                UserDefaults.standard.set(false, forKey: "family_welcome_shown")
                return
            }
            // 本人を選んだ場合: 本人オンボーディング完了済みかを確認する
            // 家族フロー経由で isOnboardingComplete が立った場合は本人オンボーディングが未経験のため通す
            let personOnboardingDone = UserDefaults.standard.bool(forKey: "person_onboarding_complete")
            if personOnboardingDone {
                // 既存の本人ユーザー: モード変更のみ
                return
            }
            // 家族フロー経由の初回本人切り替え: isOnboardingComplete をリセットしてオンボーディングへ
            appState.isOnboardingComplete = false
        }
        // オンボーディングフローへ
        if selectedMode == .person {
            appState.onboardingPath.append(OnboardingDestination.personWelcome)
        } else {
            // 家族フロー: WelcomeView でオンボーディングを行うため直接ホームへ
            UserDefaults.standard.set(false, forKey: "family_welcome_shown")
            appState.isOnboardingComplete = true
        }
    }
}
