import SwiftUI
import UIKit

/// 予定1件の行表示
/// 左端に絵文字アイコン・時刻・タイトル・削除ボタンを並べる
struct EventRow: View {
    let alarm: AlarmEvent
    var showDate: Bool = false
    let onDelete: () -> Void
    var onOpenActions: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        Group {
            if usesStackedLayout {
                largeTypeLayout
            } else {
                normalLayout
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: ComponentSize.eventRow)
        .background(cardBackground)
        .contentShape(Rectangle())
        .opacity(isPast ? 0.7 : 1.0)
        // 長押しで操作メニューを開く
        .onLongPressGesture(minimumDuration: 1.0) {
            guard let onOpenActions else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onOpenActions()
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

            VStack(alignment: .leading, spacing: Spacing.xs) {
                titleText
                metadataRow
            }

            Spacer()

            actionButton
        }
    }

    // MARK: - 巨大テキストレイアウト（P-1-12: accessibility3以上）

    private var largeTypeLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text(alarm.eventEmoji ?? "📌")
                    .font(.system(size: IconSize.xl))
                    .opacity(isPast ? 0.4 : 1.0)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if showDate {
                        Text(alarm.fireDate.japaneseCompactDateString)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if alarm.isToDo {
                        Text("いつでも")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(alarm.fireDate.japaneseTimeString)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(isPast ? .secondary : .primary)
                    }
                }
                Spacer()
                actionButton
            }

            Text(alarm.displayTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(isPast ? .secondary : .primary)
                .strikethrough(isPast, color: .secondary)
                .fixedSize(horizontal: false, vertical: true)

            metadataRow
        }
    }

    // MARK: - 共通パーツ

    private var titleText: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(alarm.displayTitle)
                .font(.body.weight(.medium))
                .foregroundStyle(isPast ? .secondary : .primary)
                .lineLimit(showDate ? 3 : 2)
                .strikethrough(isPast, color: .secondary)
                .layoutPriority(1)
                .fixedSize(horizontal: false, vertical: true)
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
    }

    @ViewBuilder
    private var metadataRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
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
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isPast {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.statusSuccess.opacity(0.8))
                .frame(width: 60, height: 60)
        } else {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(Color.statusDanger)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CornerRadius.lg)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.white.opacity(0.34))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
    }

    private var isPast: Bool {
        alarm.completionStatus != nil || (!alarm.isToDo && alarm.fireDate < Date())
    }
}
