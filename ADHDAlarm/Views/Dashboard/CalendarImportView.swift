import SwiftUI

/// カレンダーから取り込む機能（PRO）のシートView
struct CalendarImportView: View {
    @State private var viewModel: CalendarImportViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDetailSettings = false
    // 個別設定確認ダイアログの対象候補
    @State private var candidateForPerEventSetting: ImportCandidate?

    init(viewModel: CalendarImportViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? CalendarImportViewModel())
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .loading:
                    loadingView
                case .noPermission:
                    noPermissionView
                case .empty:
                    emptyView
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    candidateListView
                case .idle:
                    loadingView
                }
            }
            .navigationTitle("カレンダーから取り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        // 個別通知タイミング設定
        .confirmationDialog(
            "通知タイミングを選んでください",
            isPresented: Binding(
                get: { candidateForPerEventSetting != nil },
                set: { if !$0 { candidateForPerEventSetting = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                let label = minutes == 0 ? "ジャスト（予定の時刻ちょうど）" : "\(minutes)分前"
                Button(label) {
                    if let id = candidateForPerEventSetting?.id {
                        viewModel.perEventMinutes[id] = minutes
                    }
                    candidateForPerEventSetting = nil
                }
            }
            Button("キャンセル", role: .cancel) { candidateForPerEventSetting = nil }
        }
    }

    // MARK: - ローディング

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
            Text("Appleカレンダーを確認中…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 権限なし

    private var noPermissionView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("カレンダーの許可が必要です")
                .font(.title3.weight(.bold))
            Text("「設定」アプリからこのアプリのカレンダーアクセスを「すべてのイベント」に変更してください。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Button("設定アプリを開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.large(background: Color.owlAmber, foreground: .black))
            .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 候補なし

    private var emptyView: some View {
        VStack(spacing: Spacing.lg) {
            Text("🦉")
                .font(.system(size: 48))
            Text("取り込める予定が見つかりませんでした")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text("すでにすべて取り込み済みか、今後30日以内に予定がないかもしれません。\nくり返しの予定は今回対象外です。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            if let url = URL(string: "calshow://") {
                Link("📅 Appleカレンダーを開く", destination: url)
                    .font(.callout)
                    .foregroundStyle(Color.owlAmber)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - エラー

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("再読み込みする") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.large(background: Color.owlAmber, foreground: .black))
            .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 候補一覧

    private var candidateListView: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                calendarSelectorSection
                selectAllRow
                candidatesSection
                detailSettingsSection
                infoNote
                importButton
                calshowLink
            }
            .padding(.vertical, Spacing.md)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 取り込み中はフル画面インジケーター
            if viewModel.isImporting {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("取り込み中…")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(.regularMaterial)
            }
        }
    }

    // MARK: - カレンダー選択

    private var calendarSelectorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("取り込み元カレンダー")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.md)

            Menu {
                ForEach(viewModel.availableCalendars) { cal in
                    Button {
                        viewModel.toggleCalendar(cal.id)
                        Task { await viewModel.reloadCandidates() }
                    } label: {
                        Label(
                            cal.title,
                            systemImage: viewModel.selectedCalendarIDs.contains(cal.id)
                                ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.selectedCalendarSummary)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.md)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: - 全選択行

    private var selectAllRow: some View {
        HStack {
            Button("全部選ぶ") { viewModel.selectAll() }
                .font(.footnote)
                .foregroundStyle(Color.owlAmber)
                .frame(minHeight: 44)
            Button("全部外す") { viewModel.deselectAll() }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
            Spacer()
            Text("合計\(viewModel.candidates.count)件")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - 候補リスト

    private var candidatesSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.candidates) { candidate in
                candidateRow(candidate)
                if candidate.id != viewModel.candidates.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.secondary.opacity(0.2), lineWidth: BorderWidth.thin)
        )
        .padding(.horizontal, Spacing.md)
    }

    private func candidateRow(_ candidate: ImportCandidate) -> some View {
        HStack(spacing: Spacing.sm) {
            // チェックボックス
            Button {
                if viewModel.selectedIDs.contains(candidate.id) {
                    viewModel.selectedIDs.remove(candidate.id)
                } else {
                    viewModel.selectedIDs.insert(candidate.id)
                }
            } label: {
                Image(systemName: viewModel.selectedIDs.contains(candidate.id)
                    ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(viewModel.selectedIDs.contains(candidate.id)
                        ? Color.owlAmber : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .frame(width: 36, height: 44)

            // 日時・タイトル・カレンダー名
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.startDate.japaneseFullDateTimeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(candidate.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(candidate.calendarName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    // 個別設定済みの場合はバッジ表示
                    if let min = viewModel.perEventMinutes[candidate.id] {
                        Text(min == 0 ? "ジャスト（個別設定）" : "\(min)分前（個別設定）")
                            .font(.caption2)
                            .foregroundStyle(Color.owlAmber)
                    }
                }
            }

            Spacer()

            // 個別設定ボタン（・・・）
            Button {
                candidateForPerEventSetting = candidate
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - 詳細設定（DisclosureGroup）

    private var detailSettingsSection: some View {
        DisclosureGroup(isExpanded: $showDetailSettings) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("全体の通知タイミング")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("全体の通知タイミング", selection: $viewModel.bulkPreNotificationMinutes) {
                        Text("ジャスト（予定の時刻ちょうど）").tag(0)
                        Text("5分前").tag(5)
                        Text("10分前").tag(10)
                        Text("15分前").tag(15)
                        Text("30分前").tag(30)
                        Text("1時間前").tag(60)
                    }
                    .pickerStyle(.menu)
                    .tint(Color.owlAmber)
                }
                Text("各予定の「・・・」から個別に変更することもできます")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, Spacing.sm)
        } label: {
            Text("詳細設定（通知タイミング）")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - 注意書き

    private var infoNote: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(
                "Appleカレンダーのメモ欄に「🦉 ふくろうアプリで管理中」と追記されます",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Label(
                "くり返しの予定・終日の予定は今回対象外です",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("今後30日分を表示")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - 取り込みボタン

    private var importButton: some View {
        let count = viewModel.selectedIDs.count
        return Button {
            Task {
                await viewModel.importSelected(appState: appState)
                ToastWindowManager.shared.show(ToastMessage(text: viewModel.toastMessage, style: .owlTip))
                dismiss()
            }
        } label: {
            Group {
                if viewModel.isImporting {
                    ProgressView().tint(.white)
                } else {
                    Text(count == 0 ? "取り込む予定を選んでください" : "\(count)件まとめて取り込む")
                        .font(.title3.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ComponentSize.primary)
        }
        .buttonStyle(.large(background: count == 0 ? Color.secondary : Color.owlAmber,
                             foreground: .black))
        .disabled(count == 0 || viewModel.isImporting)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Appleカレンダーを開くリンク

    private var calshowLink: some View {
        Group {
            if let url = URL(string: "calshow://") {
                Link("📅 Appleカレンダーを開く", destination: url)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Spacing.sm)
            }
        }
    }
}

// MARK: - Date拡張（取り込みリスト用）

private extension Date {
    /// 「明日 14:00」「来週水曜 10:00」などの日本語表示
    var japaneseFullDateTimeString: String {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")

        if calendar.isDateInToday(self) {
            formatter.dateFormat = "今日 HH:mm"
        } else if calendar.isDateInTomorrow(self) {
            formatter.dateFormat = "明日 HH:mm"
        } else {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                               to: calendar.startOfDay(for: self)).day ?? 0
            if days < 7 {
                formatter.dateFormat = "E曜日 HH:mm"
            } else {
                formatter.dateFormat = "M/d(E) HH:mm"
            }
        }
        return formatter.string(from: self)
    }
}

#Preview {
    CalendarImportView()
        .environment(AppState())
}
