import SwiftUI

/// NL解析結果の確認カード
/// 「明日の15時、カフェですね。アラームをセットしますか？」
struct ParseConfirmationView: View {
    let parsed: ParsedInput
    let isLoading: Bool
    var errorMessage: String? = nil
    @Binding var selectedMinutes: Set<Int>
    let isPro: Bool
    var onUpgradeTapped: () -> Void = {}
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // コンシェルジュの確認文
            VStack(alignment: .leading, spacing: 8) {
                Text(parsed.fireDate.naturalJapaneseString)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text(parsed.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("こちらでアラームをセットしてよろしいですか？")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // イベント単位の事前通知タイミング選択
            PreNotificationPicker(
                selection: $selectedMinutes,
                isPro: isPro,
                onUpgradeTapped: onUpgradeTapped
            )

            // エラーメッセージ（セット失敗時）
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            // ボタン群（縦並び: メインアクションを上に配置して全幅を確保・文字切れ防止）
            VStack(spacing: 12) {
                // 確認ボタン（メインアクション・全幅で文字切れなし）
                Button {
                    onConfirm()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    } else {
                        // VStack で縦並びにすることで大きい文字でも文字切れしない
                        VStack(spacing: 4) {
                            Image(systemName: "alarm.fill")
                                .font(.title3)
                            Text("セットする")
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.large(background: .blue))
                .disabled(isLoading)

                // キャンセルボタン（下に配置）
                Button("やり直す", action: onCancel)
                    .buttonStyle(.large(background: Color(.systemGray5), foreground: .primary))
                    .disabled(isLoading)
            }
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
