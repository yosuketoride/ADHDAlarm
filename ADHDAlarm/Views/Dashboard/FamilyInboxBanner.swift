import SwiftUI

/// 家族から予定が届いたときに表示するふくろう吹き出しバナー
/// アラームが勝手に鳴る恐怖感を「家族からの気遣い」に変換するワンクッション
struct FamilyInboxBanner: View {
    let count: Int
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // ふくろうアイコン
            Text("🦉")
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.primary)
                Text(bodyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private var titleText: String {
        count == 1
            ? "家族から予定が届きましたよ！"
            : "家族から\(count)件の予定が届きましたよ！"
    }

    private var bodyText: String {
        "アラームも自動でセットしました。安心してね。"
    }
}
