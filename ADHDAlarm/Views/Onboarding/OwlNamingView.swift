import SwiftUI

/// オンボーディング: ふくろう命名（愛着形成）
struct OwlNamingView: View {
    @Environment(AppState.self) private var appState
    @State private var owlNameInput = ""
    @State private var showSkipFallback = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("owl_stage0_normal")
                .resizable().scaledToFit()
                .frame(width: 120, height: 120)

            Spacer().frame(height: Spacing.xl)

            Text("このふくろうに名前をつけてね")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            Spacer().frame(height: Spacing.lg)

            TextField("ふくろう", text: $owlNameInput)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(Spacing.md)
                .frame(height: ComponentSize.inputField)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.input))
                .padding(.horizontal, Spacing.md)
                .onChange(of: owlNameInput) { _, new in
                    // P-1-1: 8文字上限
                    if new.count > 8 { owlNameInput = String(new.prefix(8)) }
                }

            Spacer().frame(height: Spacing.sm)

            Text(feedbackText)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
                .animation(.easeInOut(duration: 0.2), value: owlNameInput.isEmpty)

            if showSkipFallback {
                // P-1-1: 10秒間無入力で表示するフォールバック
                Button("あとで名前をつける") {
                    proceedToNext()
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(minHeight: ComponentSize.small)
                .transition(.opacity)
            }

            Spacer()

            VStack(spacing: Spacing.sm) {
                Button("🦉 さあ、はじめよう！") {
                    proceedToNext()
                }
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.primary)
                .background(Color.owlAmber)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

                Text("名前は後から変えられます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: ComponentSize.small)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .navigationBarBackButtonHidden()
        .task(id: owlNameInput) {
            // レビュー指摘: owlNameInputが変わるたびにタスクがキャンセル・再起動される。
            // 入力中はタイマーがリセットされ、10秒間キー操作がなかった場合のみボタンを表示する。
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            withAnimation { showSkipFallback = true }
        }
    }

    private var feedbackText: String {
        owlNameInput.isEmpty
            ? "名前をつけてあげてください 🦉"
            : "🦉「よろしくね！\(owlNameInput)って呼んでもらえるの嬉しいよ！」"
    }

    private func proceedToNext() {
        appState.owlName = owlNameInput.isEmpty ? "ふくろう" : owlNameInput
        appState.onboardingPath.append(OnboardingDestination.magicDemoWarning)
    }
}
