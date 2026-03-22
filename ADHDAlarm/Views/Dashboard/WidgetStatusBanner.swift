import SwiftUI

/// ウィジェット設置状態を示すバナー
/// 設置済み → 緑✓（安心感）、未設置 → 黄⚠（ポジティブな誘導）
struct WidgetStatusBanner: View {
    let isInstalled: Bool

    var body: some View {
        // 設置済みの場合は何も表示しない（正常状態を巨大パネルで通知する必要なし）
        if !isInstalled {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("自動同期をオンにしませんか？")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("ウィジェットを置くと、アプリを閉じていても予定を確認し続けます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(16)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
