import SwiftUI

/// 予定1件の行表示
/// 左端に絵文字アイコン・時刻・タイトル・削除ボタンを並べる
struct EventRow: View {
    let alarm: AlarmEvent
    var showDate: Bool = false
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // P-1-12: accessibility3以上ではVStackレイアウトに切り替え
        let isExtremeType = dynamicTypeSize >= .accessibility3

        Group {
            if isExtremeType {
                largeTypeLayout
            } else {
                normalLayout
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

    // MARK: - 通常レイアウト

    private var normalLayout: some View {
        HStack(spacing: Spacing.md) {
            // 絵文字アイコン（左端・28pt相当）
            Text(alarm.eventEmoji ?? "📌")
                .font(.system(size: IconSize.lg))
                .opacity(isPast ? 0.4 : 1.0)
                .frame(width: IconSize.xl, alignment: .center)

            // 時刻（ToDoは「いつでも」表示）
            VStack(alignment: .center, spacing: 2) {
                if showDate {
                    Text(alarm.fireDate.japaneseDateString)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if alarm.isToDo {
                    Text("いつでも")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text(alarm.fireDate.japaneseTimeString)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(isPast ? .secondary : .primary)
                }
            }
            .frame(width: 56)

            // タイトル + サブ情報
            titleAndSubInfo

            Spacer()

            actionButton
        }
    }

    // MARK: - 巨大テキストレイアウト（P-1-12: accessibility3以上）

    private var largeTypeLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(alarm.eventEmoji ?? "📌")
                    .font(.system(size: IconSize.xl))
                    .opacity(isPast ? 0.4 : 1.0)

                if alarm.isToDo {
                    Text("いつでも")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(alarm.fireDate.japaneseTimeString)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(isPast ? .secondary : .primary)
                }
                Spacer()
                actionButton
            }
            titleAndSubInfo
        }
    }

    // MARK: - 共通パーツ

    private var titleAndSubInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 4) {
                Text(alarm.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isPast ? .secondary : .primary)
                    .lineLimit(2)
                    .strikethrough(isPast, color: .secondary)
                // ToDoバッジ（P-1-11/P-9-14）
                if alarm.isToDo && !isPast {
                    let isCarriedOver = Calendar.current.startOfDay(for: alarm.fireDate) < Calendar.current.startOfDay(for: Date())
                    Text(isCarriedOver ? "🔁 昨日から" : "ToDo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isCarriedOver ? Color.secondary : Color.owlAmber)
                        .clipShape(Capsule())
                }
            }

            if !isPast && !alarm.isToDo {
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
    }

    private var actionButton: some View {
        Group {
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
    }

    private var isPast: Bool {
        alarm.completionStatus != nil || (!alarm.isToDo && alarm.fireDate < Date())
    }
}
