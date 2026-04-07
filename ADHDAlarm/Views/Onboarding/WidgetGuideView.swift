import SwiftUI

/// オンボーディング: ウィジェット設置ガイド（TabViewカルーセル）
struct WidgetGuideView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    var onFinished: (() -> Void)? = nil

    private let pageInstructions = [
        "① ホーム画面の何もないところを\n長押しします",
        "②「＋」ボタンをタップします",
        "③「忘れ坊アラーム」を探して\nタップします",
        "④ ふくろうをホーム画面に置きます",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // カルーセル
            TabView(selection: $currentPage) {
                ForEach(Array(pageInstructions.enumerated()), id: \.offset) { index, instruction in
                    pageContent(instruction: instruction)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // ボタンエリア
            HStack(spacing: Spacing.md) {
                Button("あとでやる") {
                    finishOnboarding()
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: ComponentSize.small)
                .foregroundStyle(.secondary)

                Button(currentPage < pageInstructions.count - 1 ? "次へ →" : "できた！") {
                    if currentPage < pageInstructions.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        finishOnboarding()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.primary)
                .background(Color.owlAmber)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .navigationBarBackButtonHidden()
    }

    private func pageContent(instruction: String) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            // 画像プレースホルダー（後で実素材に差し替え）
            ZStack {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Color(.separator), lineWidth: BorderWidth.thin)
                    )
                Text("（ここに画像が入ります）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .padding(.horizontal, Spacing.md)

            Spacer().frame(height: Spacing.lg)

            Text(instruction)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            Spacer()
        }
    }

    private func finishOnboarding() {
        appState.isOnboardingComplete = true
        appState.onboardingPath = NavigationPath()
        onFinished?()
    }
}
