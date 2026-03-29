import SwiftUI

/// モード選択画面（初回起動時・設定変更時に表示）
struct ModeSelectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedMode: AppMode = .person

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("OwlIcon")
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
            // 既存ユーザー: モード変更のみ。RootView が自動切替
            return
        }
        // 初回: オンボーディングフローへ
        if selectedMode == .person {
            appState.onboardingPath.append(OnboardingDestination.personWelcome)
        } else {
            // 家族フロー（Phase 5 で本実装）: 暫定で直接ホームへ
            appState.isOnboardingComplete = true
        }
    }
}
