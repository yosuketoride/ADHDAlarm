import SwiftUI

/// ブロック組み立て式の手動入力UI（P-1-3）
/// キーボード入力を極限まで排除し、ボタンタップだけで予定を登録できる
struct PersonManualInputView: View {
    @State var viewModel: InputViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - 内部状態

    /// 選択中の予定テンプレート（nil = 未選択）
    @State private var selectedTemplate: ManualEventTemplate?
    /// 「その他」選択時のカスタムタイトル入力
    @State private var customTitle = ""
    /// 選択中の時刻プリセット
    @State private var selectedTime: TimePreset?
    /// 「時間は決めない（ToDo）」モードか否か（P-1-11）
    @State private var isToDoMode = false
    /// 「細かく設定」モードか否か
    @State private var showDatePicker = false
    /// DatePickerで選んだ日時
    @State private var pickerDate = Date()
    /// カスタムタイトルのフォーカス
    @FocusState private var isCustomFocused: Bool
    /// バリデーションエラーのシェイクトリガー
    @State private var shakeTrigger = false

    // MARK: - 予定テンプレート定義

    private let templates: [ManualEventTemplate] = [
        ManualEventTemplate(emoji: "💊", title: "くすり"),
        ManualEventTemplate(emoji: "🗑", title: "ゴミ出し"),
        ManualEventTemplate(emoji: "🏥", title: "病院"),
        ManualEventTemplate(emoji: "📞", title: "電話"),
        ManualEventTemplate(emoji: "☕", title: "カフェ"),
        ManualEventTemplate(emoji: "🛒", title: "買い物"),
        ManualEventTemplate(emoji: "✂️", title: "美容室"),
        ManualEventTemplate(emoji: "🧘", title: "体操"),
    ]

    // MARK: - 確定できるか

    private var titleText: String {
        if selectedTemplate?.isCustom == true {
            return customTitle.trimmingCharacters(in: .whitespaces)
        }
        return selectedTemplate.map { "\($0.emoji) \($0.title)" } ?? ""
    }

    private var fireDateResult: Date? {
        if isToDoMode {
            // ToDoは「時刻なし」なので、表示や翌日判定に引きずられないよう日付の先頭にそろえる。
            return Calendar.current.startOfDay(for: Date())
        }
        if showDatePicker { return pickerDate }
        return selectedTime.map { computeDate(for: $0) }
    }

    private var canConfirm: Bool {
        !titleText.isEmpty && (isToDoMode || fireDateResult != nil)
    }

    // MARK: - ビュー本体

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {

                // ─── セクション1: 何をする？ ───
                sectionHeader("🦉 何をする？")

                templateGrid

                if selectedTemplate?.isCustom == true {
                    customTitleField
                }

                // ─── セクション2: いつ？ ───
                sectionHeader("🦉 いつ？")

                timeGrid

                if showDatePicker {
                    datePickerArea
                }

                // ─── 確定ボタン ───
                confirmButton
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
        .modifier(ShakeModifier(trigger: shakeTrigger))
    }

    // MARK: - セクションヘッダー

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
    }

    // MARK: - 予定テンプレートグリッド

    private var templateGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(templates) { template in
                templateButton(template)
            }
            // 「その他」ボタン
            templateButton(ManualEventTemplate(emoji: "✏️", title: "その他", isCustom: true))
        }
    }

    private func templateButton(_ template: ManualEventTemplate) -> some View {
        let isSelected = selectedTemplate?.id == template.id
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedTemplate = template
                if !template.isCustom {
                    isCustomFocused = false
                } else {
                    // 「その他」タップ時はキーボードを出す
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isCustomFocused = true
                    }
                }
            }
        } label: {
            VStack(spacing: 6) {
                Text(template.emoji)
                    .font(.system(size: 28))
                Text(template.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72)
            .background(isSelected ? Color.owlAmber : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.owlAmber : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - カスタムタイトル入力

    private var customTitleField: some View {
        TextField("予定の内容を入力", text: $customTitle)
            .font(.body)
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .focused($isCustomFocused)
            .onChange(of: customTitle) { _, new in
                customTitle = String(new.prefix(30))
            }
    }

    // MARK: - 時間プリセットグリッド

    private var timeGrid: some View {
        VStack(spacing: 12) {
            // 朝・昼・夜 の3ボタン
            HStack(spacing: 12) {
                timeButton(.morning)
                timeButton(.noon)
                timeButton(.evening)
            }
            // 相対時間ボタン
            HStack(spacing: 12) {
                timeButton(.relative(10))
                timeButton(.relative(30))
                timeButton(.relative(60))
            }
            // 細かく設定 / 時間は決めない
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        showDatePicker.toggle()
                        if showDatePicker {
                            selectedTime = nil
                            isToDoMode = false
                        }
                    }
                } label: {
                    Text(showDatePicker ? "閉じる" : "⚙️ 細かく設定")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(showDatePicker ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(showDatePicker ? Color.blue : Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // P-1-11: 時間は決めない（ToDo）
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        isToDoMode.toggle()
                        if isToDoMode {
                            selectedTime = nil
                            showDatePicker = false
                        }
                    }
                } label: {
                    Text(isToDoMode ? "✅ 時間なし" : "⏱ 時間は決めない")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(isToDoMode ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(isToDoMode ? Color.owlAmber : Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timeButton(_ preset: TimePreset) -> some View {
        let isSelected = selectedTime == preset
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedTime = preset
                showDatePicker = false
            }
        } label: {
            VStack(spacing: 4) {
                Text(preset.emoji)
                    .font(.title3)
                Text(preset.label)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                Text(timeDescription(for: preset))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - DatePicker

    private var datePickerArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(
                "日時を選ぶ",
                selection: $pickerDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .onChange(of: pickerDate) { _, _ in
                selectedTime = nil
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }

    // MARK: - 確定ボタン

    private var confirmButton: some View {
        Button {
            guard canConfirm else {
                withAnimation(.default) { shakeTrigger.toggle() }
                return
            }
            let parsed = ParsedInput(
                title: titleText,
                fireDate: fireDateResult!,
                hasExplicitDate: true,
                isToDo: isToDoMode
            )
            viewModel.parsedInput = parsed
            // 設定済みの事前通知タイミングを引き継ぐ
            viewModel.selectedPreNotificationMinutesList = Set([15])
            viewModel.selectedFireDate = nil
            // Write-Through（カレンダー保存・AlarmKit登録）を実行してからdismiss
            // Task内でviewModelへの強参照を保持するため、dismiss後も処理が完走する
            Task { @MainActor in
                await viewModel.confirmAndSchedule()
                dismiss()
            }
        } label: {
            Text(canConfirm ? "🦉 ふくろうにお願いする" : "予定と時間を選んでね")
                .font(.title3.weight(.bold))
                .foregroundStyle(canConfirm ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 60)
                .background(canConfirm ? Color.owlAmber : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .disabled(!canConfirm)
        .buttonStyle(.plain)
    }

    // MARK: - ヘルパー

    /// TimePresetから発火日時を計算する
    private func computeDate(for preset: TimePreset) -> Date {
        let cal = Calendar.current
        let now = Date()
        switch preset {
        case .morning:
            var comp = cal.dateComponents([.year, .month, .day], from: now)
            comp.hour = 8; comp.minute = 0
            let today8am = cal.date(from: comp)!
            // 朝8時がすでに過ぎていたら明日の朝に
            return today8am > now ? today8am : cal.date(byAdding: .day, value: 1, to: today8am)!
        case .noon:
            var comp = cal.dateComponents([.year, .month, .day], from: now)
            comp.hour = 12; comp.minute = 0
            let today12 = cal.date(from: comp)!
            return today12 > now ? today12 : cal.date(byAdding: .day, value: 1, to: today12)!
        case .evening:
            var comp = cal.dateComponents([.year, .month, .day], from: now)
            comp.hour = 19; comp.minute = 0
            let today19 = cal.date(from: comp)!
            return today19 > now ? today19 : cal.date(byAdding: .day, value: 1, to: today19)!
        case .relative(let minutes):
            return now.addingTimeInterval(Double(minutes) * 60)
        }
    }

    private func timeDescription(for preset: TimePreset) -> String {
        switch preset {
        case .morning: return "8:00"
        case .noon:    return "12:00"
        case .evening: return "19:00"
        case .relative(let min):
            return min >= 60 ? "1時間後" : "\(min)分後"
        }
    }
}

// MARK: - サポート型

private struct ManualEventTemplate: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    var isCustom: Bool = false
}

private enum TimePreset: Equatable {
    case morning
    case noon
    case evening
    case relative(Int)  // 分後

    var emoji: String {
        switch self {
        case .morning:        return "☀️"
        case .noon:           return "🕛"
        case .evening:        return "🌙"
        case .relative(let m): return m < 60 ? "⏱" : "⏰"
        }
    }

    var label: String {
        switch self {
        case .morning:         return "朝"
        case .noon:            return "昼"
        case .evening:         return "夜"
        case .relative(let m): return m >= 60 ? "1時間後" : "\(m)分後"
        }
    }
}

/// 入力不足時にビューを揺らすモディファイア
private struct ShakeModifier: ViewModifier {
    var trigger: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: trigger ? 0 : 0)  // アニメーション起点
            .animation(trigger ? .interpolatingSpring(stiffness: 600, damping: 10).repeatCount(3) : .default, value: trigger)
    }
}
