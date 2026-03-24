import SwiftUI

/// NL解析結果の確認カード
/// 「明日の15時、カフェですね。アラームをセットしますか？」
struct ParseConfirmationView: View {
    let parsed: ParsedInput
    let isLoading: Bool
    var errorMessage: String? = nil
    @Binding var selectedMinutes: Set<Int>
    @Binding var selectedRecurrence: RecurrenceRule?
    var availableCalendars: [CalendarInfo] = []
    @Binding var selectedCalendarID: String?
    @Binding var selectedFireDate: Date?
    let isPro: Bool
    var onUpgradeTapped: () -> Void = {}
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var isDetailExpanded = false

    // 確認カードに表示する日時（ユーザーが変更した場合はそちらを優先）
    private var displayFireDate: Date { selectedFireDate ?? parsed.fireDate }

    // parsed.fireDateの時分を「今日」に合成した日時
    private var todayFireDate: Date {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.hour, .minute], from: parsed.fireDate)
        return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: now) ?? parsed.fireDate
    }

    // parsed.fireDateの時分を「明日」に合成した日時
    private var tomorrowFireDate: Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let comps = cal.dateComponents([.hour, .minute], from: parsed.fireDate)
        return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: tomorrow) ?? parsed.fireDate
    }

    // 今日の候補時刻がすでに過去かどうか
    private var todayIsPast: Bool { todayFireDate < Date() }

    // 明日が選択されているかどうか
    private var isNextDay: Bool {
        let cal = Calendar.current
        return cal.isDateInTomorrow(displayFireDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── ヘッダー: 日時・タイトル・今日/明日トグル ──
                VStack(alignment: .leading, spacing: 8) {
                    // 日時 + 今日/明日トグル（時間のみ発話時のみ）
                    HStack(alignment: .center, spacing: 10) {
                        Text(displayFireDate.naturalJapaneseString)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        // 日付を明示しなかった発話の場合のみトグルを表示
                        if !parsed.hasExplicitDate {
                            dateDayToggle
                        }
                    }

                    Text(parsed.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    // 繰り返しルール表示
                    if let rule = selectedRecurrence {
                        Label(rule.displayName, systemImage: "repeat")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.blue)
                    }

                    Text("アラームをセットしますか？")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // ── ボタン群（常に見える位置に配置）──
                VStack(spacing: 12) {
                    // エラーメッセージ（セット失敗時）
                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }

                    // 確認ボタン（メインアクション・全幅）
                    Button {
                        onConfirm()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity, minHeight: 60)
                        } else {
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

                    // やり直しボタン
                    Button("やり直す", action: onCancel)
                        .buttonStyle(.large(background: Color(.systemGray5), foreground: .primary))
                        .disabled(isLoading)
                }

                // ── 詳細設定（折りたたみ・ボタンの下に配置）──
                DisclosureGroup(isExpanded: $isDetailExpanded) {
                    VStack(alignment: .leading, spacing: 16) {
                        // 繰り返しルール変更ピッカー
                        VStack(alignment: .leading, spacing: 6) {
                            Text("繰り返し")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            RecurrencePicker(selection: $selectedRecurrence)
                        }

                        // カレンダー選択（PRO版かつ2つ以上のカレンダーを所持している場合のみ表示）
                        if isPro && availableCalendars.count >= 2 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("カレンダー")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Picker("カレンダー", selection: $selectedCalendarID) {
                                    ForEach(availableCalendars) { calendar in
                                        Text(calendar.title).tag(Optional(calendar.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.primary)
                            }
                        }

                        // 事前通知タイミング選択
                        PreNotificationPicker(
                            selection: $selectedMinutes,
                            isPro: isPro,
                            onUpgradeTapped: onUpgradeTapped
                        )
                    }
                    .padding(.top, 8)
                } label: {
                    Label("詳細設定", systemImage: "slider.horizontal.3")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            // NLParserが繰り返しを検出した場合は詳細設定を自動展開
            if parsed.recurrenceRule != nil {
                isDetailExpanded = true
            }
        }
    }

    // MARK: - 今日/明日トグル

    @ViewBuilder
    private var dateDayToggle: some View {
        HStack(spacing: 0) {
            dayButton("今日", date: todayFireDate, isSelected: !isNextDay, disabled: todayIsPast)
            dayButton("明日", date: tomorrowFireDate, isSelected: isNextDay, disabled: false)
        }
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func dayButton(_ label: String, date: Date, isSelected: Bool, disabled: Bool) -> some View {
        Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedFireDate = date
            }
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .strikethrough(disabled)
                .foregroundStyle(isSelected ? .white : (disabled ? Color(.systemGray3) : .secondary))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.blue : Color.clear)
                .clipShape(Capsule())
        }
        .disabled(disabled)
    }
}

// MARK: - 繰り返しルールピッカー

/// 繰り返しルールを選択する小さなセレクター
private struct RecurrencePicker: View {
    @Binding var selection: RecurrenceRule?

    private let options: [(String, RecurrenceRule?)] = [
        ("1回のみ", nil),
        ("毎日", .daily),
        ("毎週", .weekly(weekdays: [])),
        ("毎月", .monthly(day: 1)),
    ]

    var body: some View {
        HStack(spacing: 8) {
                ForEach(options, id: \.0) { label, rule in
                    let isSelected = isMatch(rule, selection)
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            selection = rule
                        }
                    } label: {
                        Text(label)
                            .font(.callout.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.blue : Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
        }
    }

    /// ルールの種類（case）が一致するか比較（associated valueは無視）
    private func isMatch(_ a: RecurrenceRule?, _ b: RecurrenceRule?) -> Bool {
        switch (a, b) {
        case (.none, .none): return true
        case (.some(.daily), .some(.daily)): return true
        case (.some(.weekly), .some(.weekly)): return true
        case (.some(.monthly), .some(.monthly)): return true
        default: return false
        }
    }
}
