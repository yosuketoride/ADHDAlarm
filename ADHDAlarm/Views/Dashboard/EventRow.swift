import SwiftUI

/// 予定1件の行表示（変更・削除ボタン付き）
struct EventRow: View {
    let alarm: AlarmEvent
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 16) {
            // 時刻（大きく表示）
            VStack(alignment: .center, spacing: 2) {
                Text(alarm.fireDate.japaneseTimeString)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isPast ? .secondary : .primary)
            }
            .frame(width: 60)

            // 予定タイトル
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isPast ? .secondary : .primary)
                    .lineLimit(2)
                    .strikethrough(isPast, color: .secondary)

                if isPast {
                    Text("お疲れ様でした！")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isPast {
                // 完了済み: チェックマーク表示
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green.opacity(0.7))
                    .frame(width: 44, height: 44)
            } else {
                // 削除ボタン（「とりけす」）
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.callout)
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isPast ? 0.7 : 1.0)
        .confirmationDialog(
            "「\(alarm.title)」のアラームをとりけしますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("とりけす", role: .destructive) { onDelete() }
            Button("やめる", role: .cancel) {}
        }
    }

    private var isPast: Bool {
        alarm.fireDate < Date()
    }

}
