import SwiftUI

/// モード選択画面（初回起動時・設定変更時に表示）
/// 「自分で使う（当事者）」か「家族として使う」かを選択する
struct ModeSelectionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // ロゴ・タイトルエリア
            VStack(spacing: Spacing.md) {
                Image("OwlIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)

                Text("忘れ坊アラーム")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text("どちらのモードで使いますか？")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // モード選択カード
            VStack(spacing: Spacing.md) {
                ModeCard(
                    title: "自分で使う",
                    subtitle: "アラームを自分でセットしたい方",
                    icon: "person.fill",
                    color: .owlAmber
                ) {
                    selectMode(.person)
                }

                ModeCard(
                    title: "家族として使う",
                    subtitle: "大切な人の予定を管理したい方",
                    icon: "person.2.fill",
                    color: .owlBrown
                ) {
                    selectMode(.family)
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }

    private func selectMode(_ mode: AppMode) {
        appState.appMode = mode
        appState.isOnboardingComplete = false
    }
}

// MARK: - モードカード

private struct ModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.lg))
                    .foregroundStyle(color)
                    .frame(width: IconSize.xl, height: IconSize.xl)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: IconSize.sm))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.md)
            .frame(minHeight: ComponentSize.eventRow)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(color.opacity(0.3), lineWidth: BorderWidth.thin)
            )
        }
        .buttonStyle(.plain)
    }
}
