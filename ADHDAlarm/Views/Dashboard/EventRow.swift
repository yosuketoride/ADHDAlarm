import SwiftUI
import UIKit

enum EventRowAppearance {
    case today
    case upcoming
}

/// 予定1件の行表示
/// 左端に絵文字アイコン・時刻・タイトル・削除ボタンを並べる
struct EventRow: View {
    let alarm: AlarmEvent
    var showDate: Bool = false
    var appearance: EventRowAppearance = .today
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
            // 絵文字アイコン（左端・Dynamic Type追従）
            Text(alarm.resolvedEmoji)
                .font(.title2)
                .opacity(iconOpacity)
                .frame(width: 24, alignment: .center)

            // 時刻（ToDoは「いつでも」表示）
            VStack(alignment: .center, spacing: 2) {
                if showDate {
                    Text(alarm.fireDate.japaneseCompactDateString)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                }
                if alarm.isToDo {
                    Text("いつでも")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(alarm.fireDate.japaneseTimeString)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(primaryTextColor)
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
                Text(alarm.resolvedEmoji)
                    .font(.system(size: IconSize.xl))
                    .opacity(iconOpacity)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if showDate {
                        Text(alarm.fireDate.japaneseCompactDateString)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(secondaryTextColor)
                    }
                    if alarm.isToDo {
                        Text("いつでも")
                            .font(.headline)
                            .foregroundStyle(secondaryTextColor)
                    } else {
                        Text(alarm.fireDate.japaneseTimeString)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(primaryTextColor)
                    }
                }
                Spacer()
                actionButton
            }

            Text(alarm.displayTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryTextColor)
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
                .foregroundStyle(primaryTextColor)
                .lineLimit(showDate ? 3 : 2)
                .strikethrough(isPast, color: .secondary)
                .layoutPriority(1)
                .fixedSize(horizontal: false, vertical: true)
            if alarm.isToDo && !isPast {
                let isCarriedOver = Calendar.current.startOfDay(for: alarm.fireDate) < Calendar.current.startOfDay(for: Date())
                Text(isCarriedOver ? "🔁 昨日から" : "ToDo")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black)
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
            if !isPast && !alarm.isToDo && (alarm.preNotificationMinutes >= 0 || isReceivedFromFamily) {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    if let notificationTimingLabel {
                        Label(notificationTimingLabel, systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }

                    if isReceivedFromFamily {
                        Label("家族から受信", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }

            if let rule = alarm.recurrenceRule {
                Label(rule.shortDisplayName, systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
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
        let isUpcoming = appearance == .upcoming && !isPast
        return RoundedRectangle(cornerRadius: CornerRadius.lg)
            .fill(isUpcoming ? Color.white.opacity(0.68) : Color.white.opacity(0.96))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(isUpcoming ? Color.midnightInk.opacity(0.20) : Color.white.opacity(0.18))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(isUpcoming ? Color.white.opacity(0.24) : Color.white.opacity(0.7), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(isUpcoming ? 0.03 : 0.05),
                radius: isUpcoming ? 6 : 8,
                x: 0,
                y: isUpcoming ? 2 : 4
            )
    }

    private var primaryTextColor: Color {
        if isPast { return Color.secondary.opacity(0.82) }
        return appearance == .upcoming ? Color.primary.opacity(0.86) : .primary
    }

    private var secondaryTextColor: Color {
        appearance == .upcoming ? Color.secondary.opacity(0.82) : .secondary
    }

    private var iconOpacity: Double {
        if isPast { return 0.4 }
        return appearance == .upcoming ? 0.82 : 1.0
    }

    private var notificationTimingLabel: String? {
        guard !alarm.isToDo else { return nil }
        let values = Array(alarm.alarmKitMinutesMap.values)
        let minutes = values.isEmpty ? [alarm.preNotificationMinutes] : values.sorted(by: >)
        return minutes.map { $0 == 0 ? "ちょうど" : "\($0)分前" }.joined(separator: "・")
    }

    private var isReceivedFromFamily: Bool {
        alarm.remoteEventId != nil
    }

    private var isPast: Bool {
        alarm.completionStatus != nil || (!alarm.isToDo && alarm.fireDate < Date())
    }
}

#Preview("Upcoming Event Row") {
    VStack(spacing: Spacing.md) {
        EventRow(
            alarm: AlarmEvent(
                title: "🛒 買い物",
                fireDate: Date().addingTimeInterval(45 * 60),
                preNotificationMinutes: 15,
                eventEmoji: "🛒"
            ),
            appearance: .upcoming,
            onDelete: {}
        )

        EventRow(
            alarm: AlarmEvent(
                title: "📌 カフェ",
                fireDate: Date(),
                eventEmoji: "📌",
                isToDo: true
            ),
            appearance: .today,
            onDelete: {}
        )

        EventRow(
            alarm: AlarmEvent(
                title: "眠りクリニック",
                fireDate: Date().addingTimeInterval(-30 * 60),
                preNotificationMinutes: 15,
                eventEmoji: "📌",
                completionStatus: .completed
            ),
            showDate: true,
            appearance: .today,
            onDelete: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
