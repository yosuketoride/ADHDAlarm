import SwiftUI

/// 家族が当事者の様子を確認するダッシュボードタブ
struct FamilyDashboardTab: View {
    var pairedPersonName: String = "ご家族"
    var lastSeen: Date? = nil
    var events: [RemoteEventRecord] = []
    var sosMessage: String? = nil
    var isPro: Bool = false
    var onUpgradeTapped: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                headerCard

                if let sosMessage, !sosMessage.isEmpty {
                    if isPro {
                        sosBanner(message: sosMessage)
                    } else {
                        lockedSOSBanner
                    }
                }

                todaySection
                historySection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.owlAmber.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "heart.text.square.fill")
                        .font(.title2)
                        .foregroundStyle(Color.owlAmber)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("\(pairedPersonName)さんの見守り")
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lastSeenText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("送った予定が相手の端末に反映されたかを、ここでまとめて確認できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // 今日の残り予定（未来のみ）
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("今日の予定")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("\(upcomingTodayEvents.count)件")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if upcomingTodayEvents.isEmpty {
                    emptyCard
                } else {
                    ForEach(upcomingTodayEvents) { event in
                        dashboardEventRow(event, isPast: false)
                    }
                }
            }

            // 今日の済んだ予定（過去分）
            if !pastTodayEvents.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("今日の済んだ予定")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(pastTodayEvents) { event in
                        dashboardEventRow(event, isPast: true)
                    }
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("過去7日間の記録")
                .font(.headline)

            if isPro {
                pastEventsSection
            } else {
                lockedHistoryCard
            }
        }
    }

    private func sosBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.statusDanger, in: Circle())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("SOSのお知らせ")
                    .font(.headline)
                    .foregroundStyle(Color.statusDanger)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.statusDanger.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private var lockedSOSBanner: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.statusDanger, in: Circle())

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("SOS通知を受け取るにはPROが必要です")
                    .font(.headline)
                    .foregroundStyle(Color.statusDanger)
                    .fixedSize(horizontal: false, vertical: true)

                Button("PROを見る") {
                    onUpgradeTapped()
                }
                .font(.callout.weight(.semibold))
                .frame(minHeight: 44)
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.statusDanger.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private var lockedHistoryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(Color.owlAmber)
                Text("過去7日間の記録はPRO機能です")
                    .font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("PROプランを見る") {
                onUpgradeTapped()
            }
            .font(.callout.weight(.semibold))
            .frame(minHeight: 44)
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private var pastEventsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if pastEventGroups.isEmpty {
                Text("過去7日間の記録はまだありません")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            } else {
                ForEach(pastEventGroups, id: \.date) { group in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(group.date.japaneseDateString)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Spacing.xs)

                        ForEach(group.events) { event in
                            dashboardEventRow(event)
                        }
                    }
                }
            }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("今日はまだ予定がありません")
                .font(.headline)
            Text("送信タブから予定を送ると、ここに反応状況が並びます。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private func dashboardEventRow(_ event: RemoteEventRecord, isPast: Bool = false) -> some View {
        HStack(spacing: Spacing.md) {
            Rectangle()
                .fill(isPast ? Color.secondary.opacity(0.3) : statusColor(for: event.status))
                .frame(width: 6)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.pill))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.fireDate.japaneseTimeString)
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        Text(event.fireDate.japaneseDateString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(minWidth: 74, alignment: .leading)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(event.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                            .strikethrough(isPast, color: .secondary)
                            .lineLimit(2)
                            .layoutPriority(1)

                        HStack(spacing: Spacing.sm) {
                            statusChip(for: event.status)
                            if let note = event.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                    }
                }

                HStack(spacing: Spacing.sm) {
                    Label("家族から送信", systemImage: "paperplane.fill")
                    Text(preNotificationText(for: event.preNotificationMinutes))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: ComponentSize.eventRow)
        .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    private func statusChip(for status: String) -> some View {
        Text(statusLabel(for: status))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(statusColor(for: status), in: Capsule())
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "pending", "alerting":
            return .owlAmber
        case "synced":
            return .statusSuccess
        case "completed":
            return .statusSuccess
        case "skipped":
            return .statusSkipped
        case "missed", "expired":
            return .statusDanger
        case "snoozed":
            return .statusWarning
        case "cancelled":
            return .secondary
        default:
            return .statusPending
        }
    }

    private func statusLabel(for status: String) -> String {
        switch status {
        case "pending":
            return "待機中"
        case "alerting":
            return "通知中"
        case "synced":
            return "受信済み"
        case "completed":
            return "完了"
        case "skipped":
            return "スキップ"
        case "missed":
            return "未対応"
        case "expired":
            return "期限切れ"
        case "snoozed":
            return "あとで"
        case "cancelled":
            return "取消済み"
        default:
            return status
        }
    }

    private func preNotificationText(for minutes: Int) -> String {
        minutes == 0 ? "時間ちょうどに通知" : "\(minutes)分前に通知"
    }

    private var todaysEvents: [RemoteEventRecord] {
        let calendar = Calendar.current
        return events
            .filter { calendar.isDateInToday($0.fireDate) }
            .sorted { $0.fireDate < $1.fireDate }
    }

    /// 今日の予定のうち、まだ時間が来ていないもの
    private var upcomingTodayEvents: [RemoteEventRecord] {
        todaysEvents.filter { $0.fireDate > Date() }
    }

    /// 今日の予定のうち、すでに時間が過ぎたもの（新しい順）
    private var pastTodayEvents: [RemoteEventRecord] {
        todaysEvents.filter { $0.fireDate <= Date() }.reversed()
    }

    private var pastEventGroups: [(date: Date, events: [RemoteEventRecord])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        let filtered = events.filter { event in
            let day = calendar.startOfDay(for: event.fireDate)
            return day >= startDate && day < today
        }

        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.fireDate) }
        return grouped
            .map { (date: $0.key, events: $0.value.sorted { $0.fireDate < $1.fireDate }) }
            .sorted { $0.date > $1.date }
            .prefix(7)
            .map { $0 }
    }

    private var lastSeenText: String {
        guard let lastSeen else { return "まだ相手の端末への反映は確認できていません" }
        guard isPro else {
            let hours = Date().timeIntervalSince(lastSeen) / 3600
            switch hours {
            case ..<1:
                return "最終反映: 1時間以内 🟢"
            case ..<6:
                return "最終反映: 数時間前 🟡"
            default:
                return "最終反映: 6時間以上前 🔴"
            }
        }
        return "最終反映: \(lastSeen.japaneseDateString) \(lastSeen.japaneseTimeString)"
    }
}
