import SwiftUI

/// 予定1件の行表示
/// 左端に絵文字アイコン・時刻・タイトル・削除ボタンを並べる
struct EventRow: View {
    let alarm: AlarmEvent
    var showDate: Bool = false
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // 絵文字アイコン（左端・28pt相当）
            Text(alarm.eventEmoji ?? "📌")
                .font(.system(size: IconSize.lg))
                .opacity(isPast ? 0.4 : 1.0)
                .frame(width: IconSize.xl, alignment: .center)

            // 時刻
            VStack(alignment: .center, spacing: 2) {
                if showDate {
                    Text(alarm.fireDate.japaneseDateString)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(alarm.fireDate.japaneseTimeString)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isPast ? .secondary : .primary)
            }
            .frame(width: 56)

            // タイトル + サブ情報
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isPast ? .secondary : .primary)
                    .lineLimit(2)
                    .strikethrough(isPast, color: .secondary)

                if !isPast {
                    let values = Array(alarm.alarmKitMinutesMap.values)
                    let minutes = values.isEmpty ? [alarm.preNotificationMinutes] : values.sorted(by: >)
                    let timingLabel = minutes.map { $0 == 0 ? "ちょうど" : "\($0)分前" }.joined(separator: "・")
                    Label(timingLabel, systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let rule = alarm.recurrenceRule {
                    Label(rule.shortDisplayName, systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isPast {
                    Text("お疲れ様でした！")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isPast {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.statusSuccess.opacity(0.7))
                    .frame(width: ComponentSize.small, height: ComponentSize.small)
            } else {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.callout)
                        .foregroundStyle(Color.statusDanger.opacity(0.7))
                        .frame(width: ComponentSize.small, height: ComponentSize.small)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: ComponentSize.eventRow)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .opacity(isPast ? 0.7 : 1.0)
        .confirmationDialog(
            "「\(alarm.title)」を削除しますか？（iPhoneのカレンダーからも消えます）",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) { onDelete() }
            Button("やめる", role: .cancel) {}
        }
    }

    private var isPast: Bool {
        alarm.fireDate < Date()
    }
}
