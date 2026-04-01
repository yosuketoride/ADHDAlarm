import SwiftUI
import UIKit

/// 予定1件の行表示
/// 左端に絵文字アイコン・時刻・タイトル・削除ボタンを並べる
struct EventRow: View {
    let alarm: AlarmEvent
    var showDate: Bool = false
    let onDelete: () -> Void
    var onComplete: (() -> Void)? = nil

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
        .contentShape(Rectangle())
        .opacity(isPast ? 0.7 : 1.0)
        // 長押し（1秒）で完了（高齢者向けに確実に反応させる）
        .onLongPressGesture(minimumDuration: 1.0) {
            guard !isPast else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onComplete?()
        }
        // スワイプ右: 完了（誤操作防止でアイコン表示のみ）
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !isPast {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onComplete?()
                } label: {
                    Label("完了", systemImage: "checkmark.circle.fill")
                }
                .tint(Color.statusSuccess)
            }
        }
        // スワイプ左: 削除（confirmationDialogは親で管理）
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - 通常レイアウト

    private var normalLayout: some View {
        HStack(spacing: Spacing.sm) {
            // 絵文字アイコン（左端・固定20pt・Dynamic Type非スケール）
            Text(alarm.eventEmoji ?? "📌")
                .font(.system(size: 20))
                .opacity(isPast ? 0.4 : 1.0)
                .frame(width: 24, alignment: .center)

            // 時刻（ToDoは「いつでも」表示）
            VStack(alignment: .center, spacing: 2) {
                if showDate {
                    Text(alarm.fireDate.japaneseCompactDateString)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                }
                if alarm.isToDo {
                    Text("いつでも")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(alarm.fireDate.japaneseTimeString)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(isPast ? .secondary : .primary)
                }
            }
            .frame(minWidth: showDate ? 54 : 60)

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
                    .lineLimit(showDate ? 3 : 2)
                    .strikethrough(isPast, color: .secondary)
                    .layoutPriority(1)
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
            } else if !isPast {
                // 操作ヒント（長押し完了 / スワイプ削除）
                Text("長押しで完了 ・ 左スワイプで削除")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // 完了済みのみチェックマークを表示（未完了はスワイプ/長押しで操作）
    @ViewBuilder
    private var actionButton: some View {
        if isPast {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.statusSuccess.opacity(0.7))
                .frame(width: 36, height: 36)
        }
    }

    private var isPast: Bool {
        alarm.completionStatus != nil || (!alarm.isToDo && alarm.fireDate < Date())
    }
}
