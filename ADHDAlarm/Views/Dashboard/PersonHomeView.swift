import SwiftUI
import UIKit

/// 当事者モードのホーム画面
/// タブレス・1画面集約・ストレス排除設計
struct PersonHomeView: View {
    private static let transitionGapHeight: CGFloat = ComponentSize.eventRow + Spacing.lg

    @State private var viewModel: PersonHomeViewModel
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(PermissionsService.self) private var permissionsService
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @SceneStorage("isEventListExpanded") private var storedIsEventListExpanded = false
    private let loadsEventsOnTask: Bool
    private let previewHour: Int?

    // フクロウ首傾けアニメ用
    @State private var owlNeckTilt: Double = 0

    private var eventListTransition: AnyTransition {
        accessibilityReduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    private var expandCollapseAnimation: Animation {
        accessibilityReduceMotion ? .easeOut(duration: 0.18) : .easeInOut(duration: 0.3)
    }
    @State private var owlFloatOffset: CGFloat = -6
    // レビュー指摘: confirmationDialog は親に1つだけ配置する（EventRow側から移動）
    @State private var eventToDelete: AlarmEvent?
    @State private var eventToActOn: AlarmEvent?
    // PRO機能ゲート用
    @State private var showPaywall = false
    @State private var micInputViewModel: InputViewModel?

    @MainActor
    init(
        viewModel: PersonHomeViewModel? = nil,
        loadsEventsOnTask: Bool = true,
        previewHour: Int? = nil
    ) {
        _viewModel = State(initialValue: viewModel ?? PersonHomeViewModel())
        self.loadsEventsOnTask = loadsEventsOnTask
        self.previewHour = previewHour
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                // レイヤー1（最背面）: 時間帯グラデーション背景
                TimeOfDayBackground(previewHour: previewHour)
                    .ignoresSafeArea(edges: hasTomorrowCards ? .top : .all)

                // レイヤー2: メインコンテンツ（スクロール可能）
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        owlSection
                            .padding(.top, Spacing.xs)
                        middleZone
                        if hasTomorrowCards {
                            zoneTransitionBand
                            bottomZone
                        }
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .refreshable { await viewModel.performManualSync() }

                // レイヤー3（最前面）: マイクFAB
                micFAB
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.md)
            }
            .onAppear {
                viewModel.updateScreenHeightIfNeeded(proxy.size.height)
            }
            .onChange(of: proxy.size.height) { _, newHeight in
                viewModel.updateScreenHeightIfNeeded(newHeight)
            }
            .background(hasTomorrowCards ? AnyView(bottomZoneBackground) : AnyView(Color.clear))
        }
        // Toast（シェイク等の通知）
        .overlay(alignment: .top) {
            if let msg = viewModel.confirmationMessage {
                toastBanner(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, Spacing.md)
            }
        }
        .overlay {
            if permissionsService.hasDeniedPermissions {
                permissionBlockedOverlay
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 0) {
                Button {
                    Task { await viewModel.performManualSync() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: IconSize.sm))
                        .foregroundStyle(upperSecondaryTextColor)
                        .frame(width: 60, height: 60)
                }

                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: IconSize.md))
                        .foregroundStyle(upperSecondaryTextColor)
                        .frame(width: 60, height: 60)
                }
            }
            .padding(.top, Spacing.sm)
            .padding(.trailing, Spacing.lg)
        }
        // マイク入力シート
        .sheet(isPresented: $viewModel.showMicSheet, onDismiss: {
            router.isMicSheetOpen = false
            Task { await viewModel.loadEvents() }
        }) {
            Group {
                if let micInputViewModel {
                    MicrophoneInputView(
                        viewModel: micInputViewModel,
                        onSaved: {
                            Task { await viewModel.loadEvents() }
                            viewModel.showMicSheet = false
                        }
                    )
                } else {
                    VStack(spacing: Spacing.md) {
                        ProgressView()
                        Text("マイクの準備をしています…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .task {
                        prepareMicInputViewModelIfNeeded()
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // 設定シート
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: SettingsViewModel(appState: appState))
        }
        // カレンダーから取り込む（PRO）
        .sheet(isPresented: $viewModel.showCalendarImport, onDismiss: {
            Task { await viewModel.loadEvents() }
        }) {
            CalendarImportView()
                .environment(appState)
                .presentationDetents([.medium, .large])
        }
        // ペイウォール（PROボタンを非PROユーザーがタップした場合）
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // テキスト手動入力シート（P-1-3）
        // onDismiss: confirmAndSchedule()完走後にdismissされるため、ここでloadEventsすれば確実に反映される
        .sheet(isPresented: $viewModel.showManualInput, onDismiss: {
            Task { await viewModel.loadEvents() }
        }) {
            NavigationStack {
                PersonManualInputView(
                    viewModel: InputViewModel(appState: appState),
                    onSaved: {
                        Task { await viewModel.loadEvents() }
                    }
                )
                    .navigationTitle("予定を追加")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { viewModel.showManualInput = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        // 削除アンドゥバナー
        .overlay(alignment: .bottom) {
            if viewModel.pendingDelete != nil {
                undoBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, ComponentSize.fab + Spacing.xl)
            } else if viewModel.pendingComplete != nil {
                completeUndoBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, ComponentSize.fab + Spacing.xl)
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.confirmationMessage != nil)
        .animation(.spring(duration: 0.3), value: viewModel.pendingDelete != nil)
        .animation(.spring(duration: 0.3), value: viewModel.pendingComplete != nil)
        .onShake { viewModel.handleOwlShake() }
        .onChange(of: router.ringingAlarm?.id) { _, newValue in
            if newValue != nil {
                viewModel.dismissPresentedSheets()
            }
        }
        .onAppear {
            viewModel.isEventListExpanded = storedIsEventListExpanded
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                owlFloatOffset = 6
            }
        }
        .onChange(of: storedIsEventListExpanded) { _, newValue in
            viewModel.isEventListExpanded = newValue
        }
        .task {
            viewModel.bindAppStateIfNeeded(appState)
            prepareMicInputViewModelIfNeeded()
            if loadsEventsOnTask {
                await viewModel.loadEvents()
            }
            await refreshFamilyPremiumIfNeeded()
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(get: { eventToDelete != nil }, set: { if !$0 { eventToDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let alarm = eventToDelete, alarm.recurrenceGroupID != nil {
                Button("今回のみ削除する", role: .destructive) {
                    Task { await viewModel.deleteEvent(alarm) }
                    eventToDelete = nil
                }
                Button("繰り返しを全部削除する", role: .destructive) {
                    Task { await viewModel.deleteRecurringSeries(alarm) }
                    eventToDelete = nil
                }
            } else {
                Button("削除する", role: .destructive) {
                    if let alarm = eventToDelete {
                        Task { await viewModel.deleteEvent(alarm) }
                    }
                    eventToDelete = nil
                }
            }
            Button("やめる", role: .cancel) { eventToDelete = nil }
        }
        .confirmationDialog(
            actionDialogTitle,
            isPresented: Binding(get: { eventToActOn != nil }, set: { if !$0 { eventToActOn = nil } }),
            titleVisibility: .visible
        ) {
            if let alarm = eventToActOn {
                if alarm.completionStatus == nil || alarm.completionStatus == .missed {
                    Button("完了にする") {
                        Task { await viewModel.completeEvent(alarm) }
                        eventToActOn = nil
                    }
                    // ToDoタスクは翌日に繰り越すことができる
                    if alarm.isToDo {
                        Button("今日はスキップ（明日に繰り越す）") {
                            viewModel.skipAndCarryOverToDo(alarm)
                            eventToActOn = nil
                        }
                    }
                }
                if alarm.recurrenceGroupID != nil {
                    Button("今回のみ削除する", role: .destructive) {
                        Task { await viewModel.deleteEvent(alarm) }
                        eventToActOn = nil
                    }
                    Button("繰り返しを全部削除する", role: .destructive) {
                        Task { await viewModel.deleteRecurringSeries(alarm) }
                        eventToActOn = nil
                    }
                } else {
                    Button("削除する", role: .destructive) {
                        Task { await viewModel.deleteEvent(alarm) }
                        eventToActOn = nil
                    }
                }
            }
            Button("やめる", role: .cancel) { eventToActOn = nil }
        }
    }

    // MARK: - フクロウセクション（Zone 1: 時間帯オーバーレイなし）

    private var owlSection: some View {
        ZStack {
            // フクロウ（中央）
            owlImage
                .frame(width: 120, height: 120)
                .offset(y: owlFloatOffset + 30)
                .rotationEffect(.degrees(owlNeckTilt))
                .onTapGesture { handleOwlTap() }
                .onLongPressGesture(minimumDuration: 0.8) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.showSettings = true
                }

            // 吹き出し（フクロウの斜め上左）
            VStack(spacing: 0) {
                HStack {
                    greetingBubble
                        .offset(x: 30, y: 30)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(height: 182)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - 吹き出しあいさつ（青・白文字・右下テール）

    private var greetingBubble: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(viewModel.greeting)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.statusPending)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .shadow(color: Color.statusPending.opacity(0.25), radius: 4, x: 0, y: 2)

            // テール：右下向き（ふくろう方向へ向かう）
            BubbleTailDownRight()
                .fill(Color.statusPending)
                .frame(width: 10, height: 8)
                .padding(.trailing, Spacing.sm)
        }
        .frame(width: 136, alignment: .leading)
    }

    // MARK: - 吹き出し三角シェイプ（右下向き）

    private struct BubbleTailDownRight: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))    // 左上
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))  // 右上
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))  // 右下（頂点）
            p.closeSubpath()
            return p
        }
    }

    @ViewBuilder
    private var owlImage: some View {
        // XP（ステージ）× owlState（感情）に応じたアセットを表示
        // フォールバック: normal → OwlIcon の順
        let imageName = viewModel.owlImageName()
        Image(imageName)
            .resizable()
            .renderingMode(.original) // テンプレートモードによるモノクロ化を防ぐ
            .scaledToFit()
//            .saturation(viewModel.owlState == .sleepy ? 0.4 : 1.0)
//            .scaleEffect(viewModel.owlState == .happy ? 1.1 : 1.0)
            .saturation(1.0)
            .animation(.spring(duration: 0.3, bounce: 0.6), value: viewModel.owlState)
    }

    // MARK: - カウントダウンセクション

    private var middleZone: some View {
        VStack(spacing: 0) {
            countdownSection
            eventListSection
                .padding(.top, Spacing.lg)
            if hasTodayCards && hasTomorrowCards {
                Spacer()
                    .frame(height: Self.transitionGapHeight)
            }
        }
        .background(middleZoneBackground)
    }

    private var bottomZone: some View {
        VStack(spacing: 0) {
            tomorrowSection
            Spacer(minLength: ComponentSize.fab + Spacing.xl)
        }
        .background(bottomZoneExtendedBackground)
    }

    @ViewBuilder
    private var countdownSection: some View {
        if let next = viewModel.nextAlarm {
            // 通知が鳴るまでの残り時間を基準にカウントダウンする（fireDate - preNotificationMinutes）
            let notificationDate = next.fireDate.addingTimeInterval(-Double(next.preNotificationMinutes) * 60)
            let minutes = notificationDate.timeIntervalSinceNow / 60
            nextAlarmCard(alarm: next, minutes: Int(minutes))
            .padding(.top, Spacing.lg)
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func nextAlarmCard(alarm: AlarmEvent, minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Text(alarm.resolvedEmoji)
                    .font(.system(size: IconSize.lg))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(nextAlarmTimingText(minutes: minutes, alarm: alarm))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(minutes < 10 ? Color.statusDanger : .secondary)
                    Text(alarm.displayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    nextAlarmMetadataRow(alarm: alarm)
                }
                Spacer()
                Button(role: .destructive) {
                    eventToDelete = alarm
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(Color.statusDanger)
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
            }

            if minutes < 10 {
                Capsule()
                    .fill(Color.statusDanger.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.statusDanger.opacity(0.55))
                            .frame(maxWidth: max(24, 220 * CGFloat(max(0, minutes)) / 10.0))
                    }
                    .frame(height: 6)
            } else {
                Capsule()
                    .fill(Color.owlAmber.opacity(0.18))
                    .frame(height: 4)
            }
        }
        .padding(Spacing.md)
        .background(glassCardBackground(accent: minutes < 10 ? Color.statusDanger : Color.owlAmber))
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.0) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            eventToActOn = alarm
        }
    }

    @ViewBuilder
    private func nextAlarmMetadataRow(alarm: AlarmEvent) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            if let timingLabel = notificationTimingLabel(for: alarm) {
                Label(timingLabel, systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if alarm.remoteEventId != nil {
                Label("家族から受信", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func nextAlarmTimingText(minutes: Int, alarm: AlarmEvent) -> String {
        if minutes < 1 {
            return "まもなくお知らせ • 予定 \(alarm.fireDate.japaneseTimeString)"
        }
        return "あと\(minutes)分でお知らせ • 予定 \(alarm.fireDate.japaneseTimeString)"
    }

    private func notificationTimingLabel(for alarm: AlarmEvent) -> String? {
        guard !alarm.isToDo else { return nil }
        let values = Array(alarm.alarmKitMinutesMap.values)
        let minutes = values.isEmpty ? [alarm.preNotificationMinutes] : values.sorted(by: >)
        return minutes.map { $0 == 0 ? "ちょうど" : "\($0)分前" }.joined(separator: "・")
    }

    // MARK: - 予定リストセクション

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // セクションヘッダー
            Text("── 今日の予定 ──")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(upperSecondaryTextColor)
                .padding(.horizontal, Spacing.lg)

            // 未完了の予定がゼロの場合に空状態メッセージを表示
            // （完了済みが残っていても未完了がゼロなら空状態）
            if viewModel.visibleEvents.isEmpty && viewModel.completedTodayEvents.isEmpty {
                emptyStateView
            } else {
                // 未完了の予定（折りたたみ）
                ForEach(viewModel.visibleEvents) { alarm in
                    EventRow(
                        alarm: alarm,
                        appearance: .today,
                        onDelete: {
                            eventToDelete = alarm
                        },
                        onOpenActions: {
                            eventToActOn = alarm
                        }
                    )
                    .padding(.horizontal, Spacing.md)
                    .transition(eventListTransition)
                }

                // 折りたたみボタン
                if viewModel.shouldShowExpandButton {
                    Button {
                        withAnimation(expandCollapseAnimation) {
                            viewModel.isEventListExpanded = true
                            storedIsEventListExpanded = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("＋ 残り\(viewModel.hiddenEventCount)件を表示")
                                .font(.subheadline)
                                .foregroundStyle(upperSecondaryTextColor)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(upperSecondaryTextColor)
                            Spacer()
                        }
                        .frame(minHeight: ComponentSize.small)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, Spacing.md)
                }

                if viewModel.shouldShowCollapseButton {
                    Button {
                        withAnimation(expandCollapseAnimation) {
                            viewModel.isEventListExpanded = false
                            storedIsEventListExpanded = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.up")
                                .font(.caption)
                                .foregroundStyle(upperSecondaryTextColor)
                            Text("折りたたむ")
                                .font(.subheadline)
                                .foregroundStyle(upperSecondaryTextColor)
                            Spacer()
                        }
                        .frame(minHeight: ComponentSize.small)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, Spacing.md)
                }


            }

            if !viewModel.completedTodayEvents.isEmpty {
                ForEach(viewModel.completedTodayEvents) { alarm in
                    EventRow(alarm: alarm, appearance: .today) {
                        eventToDelete = alarm
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    // MARK: - 空状態ビュー

    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            let info = viewModel.emptyStateInfo
            Text(info.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(upperSecondaryTextColor)
                .padding(.horizontal, Spacing.xl)

            if viewModel.events.isEmpty {
                shortcutButtonsRow(
                    voiceLabel: info.ctaLabel,
                    textLabel: "✏️ テキストで追加",
                    font: .subheadline
                )
                // カレンダーから取り込むボタン（PRO機能）
                Button("📅 カレンダーから取り込む") {
                    if appState.subscriptionTier == .pro {
                        viewModel.showCalendarImport = true
                    } else {
                        showPaywall = true
                    }
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(upperSecondaryTextColor)
                .frame(minHeight: 44)
            }

            // デイリーミニタスク（P-1-5）: 全完了時のみ
            if viewModel.completedTodayEvents.count > 0 && !viewModel.isMiniTaskCompletedToday {
                Button {
                    viewModel.completeDailyMiniTask()
                } label: {
                    Text(viewModel.dailyMiniTask)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - ManualInputシート用状態
    // (showManualInput は PersonHomeViewModel に追加)

    // MARK: - 明日以降の予定セクション（Zone 3: 夜テーマ）

    @ViewBuilder
    private var tomorrowSection: some View {
        if !viewModel.tomorrowEvents.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(viewModel.tomorrowEvents) { alarm in
                    EventRow(
                        alarm: alarm,
                        showDate: true,
                        appearance: .upcoming,
                        onDelete: {
                            eventToDelete = alarm
                        },
                        onOpenActions: {
                            eventToActOn = alarm
                        }
                    )
                    .padding(.horizontal, Spacing.md)
                    .transition(eventListTransition)
                }

                // 明日以降の折りたたみ/展開ボタン
                if viewModel.shouldShowUpcomingExpandButton {
                    Button {
                        withAnimation(expandCollapseAnimation) {
                            viewModel.isUpcomingListExpanded = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("＋ 残り\(viewModel.hiddenUpcomingCount)件を表示")
                                .font(.subheadline)
                                .foregroundStyle(lowerSecondaryTextColor)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(lowerSecondaryTextColor)
                            Spacer()
                        }
                        .frame(minHeight: ComponentSize.small)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, Spacing.md)
                }

                if viewModel.shouldShowUpcomingCollapseButton {
                    Button {
                        withAnimation(expandCollapseAnimation) {
                            viewModel.isUpcomingListExpanded = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.up")
                                .font(.caption)
                                .foregroundStyle(lowerSecondaryTextColor)
                            Text("折りたたむ")
                                .font(.subheadline)
                                .foregroundStyle(lowerSecondaryTextColor)
                            Spacer()
                        }
                        .frame(minHeight: ComponentSize.small)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, Spacing.md)
                }

                // カレンダーから取り込むボタン（PRO機能）
                Button("📅 カレンダーから取り込む") {
                    if appState.subscriptionTier == .pro {
                        viewModel.showCalendarImport = true
                    } else {
                        showPaywall = true
                    }
                }
                .font(.footnote)
                .foregroundStyle(lowerSecondaryTextColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    private var zoneTransitionBand: some View {
        VStack(spacing: 0) {
            Text("ここから明日以降")
                .font(.caption.weight(.medium))
                .foregroundStyle(transitionLabelColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(zoneTransitionBackground)
    }

    // MARK: - マイクFAB

    private var micFAB: some View {
        Button {
            prepareMicInputViewModelIfNeeded()
            viewModel.showMicSheet = true
            router.isMicSheetOpen = true
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: "mic.fill")
                    .font(.system(size: shouldUseExpandedMicFAB ? 44 : IconSize.md, weight: .bold))
                if !shouldUseExpandedMicFAB {
                    Text("予定を追加")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(.black)
            .frame(
                width: shouldUseExpandedMicFAB ? 112 : ComponentSize.fab,
                height: shouldUseExpandedMicFAB ? 112 : ComponentSize.fab
            )
            .background(Color.owlAmber)
            .clipShape(Circle())
            .contentShape(Circle())
            .shadow(color: Color.owlAmber.opacity(0.4), radius: 8, y: 4)
        }
        .accessibilityLabel("予定を追加")
    }

    private var shouldHideInlineShortcutButtons: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private var shouldUseExpandedMicFAB: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private var shouldStackShortcutButtons: Bool {
        dynamicTypeSize >= .xxxLarge
    }

    @ViewBuilder
    private func shortcutButtonsRow(
        voiceLabel: String,
        textLabel: String,
        font: Font
    ) -> some View {
        if shouldStackShortcutButtons {
            VStack(spacing: Spacing.sm) {
                shortcutButton(title: voiceLabel, font: font) {
                    prepareMicInputViewModelIfNeeded()
                    viewModel.showMicSheet = true
                    router.isMicSheetOpen = true
                }
                shortcutButton(title: textLabel, font: font) {
                    viewModel.showManualInput = true
                }
            }
        } else {
            HStack(spacing: Spacing.md) {
                shortcutButton(title: voiceLabel, font: font) {
                    prepareMicInputViewModelIfNeeded()
                    viewModel.showMicSheet = true
                    router.isMicSheetOpen = true
                }

                Text("｜")
                    .font(font)
                    .foregroundStyle(upperSecondaryTextColor.opacity(0.82))

                shortcutButton(title: textLabel, font: font) {
                    viewModel.showManualInput = true
                }
            }
        }
    }

    private func prepareMicInputViewModelIfNeeded() {
        if micInputViewModel == nil {
            micInputViewModel = InputViewModel(appState: appState)
        } else {
            micInputViewModel?.reset()
        }
    }

    private func shortcutButton(
        title: String,
        font: Font,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(title)
                    .font(font)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.owlAmber)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: ComponentSize.small)
            .background(glassCardBackground(accent: Color.owlAmber, cornerRadius: CornerRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.owlAmber.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - トーストバナー

    private func toastBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Undoバナー

    private var undoBanner: some View {
        HStack {
            if let deleted = viewModel.pendingDelete {
                Text("「\(deleted.title)」を削除します")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button("もとに戻す") {
                withAnimation { viewModel.undoDelete() }
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.owlAmber)
        }
        .padding(Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    private var completeUndoBanner: some View {
        HStack {
            if let completed = viewModel.pendingComplete {
                Text("「\(completed.title)」を完了にしました")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button("もとに戻す") {
                withAnimation { viewModel.undoComplete() }
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.owlAmber)
        }
        .padding(Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - フクロウタップハンドラ

    private func handleOwlTap() {
        let roll = Int.random(in: 0..<100)
        // 首傾けアニメ（20%）
        if roll >= 70 && roll < 90 {
            withAnimation(.easeInOut(duration: 0.15).repeatCount(2, autoreverses: true)) {
                owlNeckTilt = 15
            }
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation { owlNeckTilt = 0 }
            }
        }
        viewModel.handleOwlTap()
    }

    private var deleteDialogTitle: String {
        guard let alarm = eventToDelete else { return "予定を削除しますか？" }
        if alarm.recurrenceGroupID != nil {
            return "「\(alarm.title)」は繰り返し予定です。今回だけ削除するか、繰り返しを全部削除するか選んでください。"
        }
        return "「\(alarm.title)」を削除しますか？（iPhoneのカレンダーからも消えます）"
    }

    private func refreshFamilyPremiumIfNeeded() async {
        guard appState.subscriptionTier == .free else { return }
        guard appState.familyLinkId != nil || !appState.familyChildLinkIds.isEmpty else { return }

        do {
            let links = try await FamilyRemoteService.shared.fetchMyFamilyLinks()
            if links.contains(where: { $0.isPremium }) {
                appState.subscriptionTier = .pro
            }
        } catch {
            // 取得失敗時は現在値を維持し、次回の前面復帰や設定再表示で再判定する
        }
    }

    private var actionDialogTitle: String {
        guard let alarm = eventToActOn else { return "予定をどうしますか？" }
        if alarm.completionStatus == .missed {
            return "「\(alarm.title)」をどうしますか？"
        }
        if alarm.completionStatus != nil {
            return "「\(alarm.title)」を削除しますか？"
        }
        return "「\(alarm.title)」をどうしますか？"
    }

    private var permissionBlockedOverlay: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.owlAmber)
            Text("設定の確認が必要です")
                .font(.title3.weight(.bold))
            Text("マイクやカレンダーの許可がオフになっています。設定アプリで許可すると、いつものように使えます。")
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .ignoresSafeArea()
    }

    private var middleZoneBackground: some View {
        guard hasTomorrowCards else { return AnyView(Color.clear) }
        let palette = currentBackgroundPalette
        let isNight = palette.phase == .night
        return AnyView(LinearGradient(
            stops: [
                .init(color: Color.clear, location: 0.00),
                .init(color: Color.clear, location: 0.82),
                .init(color: isNight ? Color.midnightInk : palette.boundary.opacity(0.10), location: 0.94),
                .init(color: isNight ? Color.midnightInk : palette.boundary.opacity(0.22), location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        ))
    }

    private var zoneTransitionBackground: some View {
        let palette = currentBackgroundPalette
        let isNight = palette.phase == .night
        return LinearGradient(
            stops: [
                .init(color: isNight ? Color.midnightInk : palette.boundary.opacity(0.22), location: 0.00),
                .init(color: isNight ? Color.midnightInk : palette.boundary.opacity(0.12), location: 0.24),
                .init(color: Color.midnightInk.opacity(0.94), location: 0.72),
                .init(color: Color.midnightInk, location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var bottomZoneBackground: some View {
        LinearGradient(
            stops: [
                .init(color: Color.midnightInk, location: 0.00),
                .init(color: Color.midnightInk, location: 0.20),
                .init(color: Color.midnightInk, location: 0.52),
                .init(color: Color.midnightBlack, location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private var bottomZoneExtendedBackground: some View {
        VStack(spacing: 0) {
            bottomZoneBackground
            Color.midnightBlack
                .frame(height: 1000)
        }
        .padding(.bottom, -1000)
        .allowsHitTesting(false)
    }

    private var currentBackgroundPalette: HomeBackgroundPalette {
        if let previewHour {
            return HomeBackgroundPalette.forHour(previewHour)
        }
        return HomeBackgroundPalette.forDate(Date())
    }

    private var hasTodayCards: Bool {
        !viewModel.visibleEvents.isEmpty || !viewModel.completedTodayEvents.isEmpty
    }

    private var hasTomorrowCards: Bool {
        !viewModel.tomorrowEvents.isEmpty
    }

    private var upperPrimaryTextColor: Color {
        currentBackgroundPalette.usesLightUpperText ? Color.white.opacity(0.94) : Color.black.opacity(0.86)
    }

    private var upperSecondaryTextColor: Color {
        currentBackgroundPalette.usesLightUpperText ? Color.white.opacity(0.72) : Color.black.opacity(0.58)
    }

    private var lowerPrimaryTextColor: Color {
        Color.white.opacity(0.92)
    }

    private var lowerSecondaryTextColor: Color {
        Color.white.opacity(0.72)
    }

    private var transitionLabelColor: Color {
        Color.white.opacity(currentBackgroundPalette.phase == .night ? 0.76 : 0.88)
    }

    private func glassCardBackground(
        accent: Color,
        cornerRadius: CGFloat = CornerRadius.lg
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.secondarySystemBackground).opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.54),
                                accent.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

#Preview("Person Home • Dawn") {
    PersonHomeView.previewScreen(hour: 5, owlXP: 0)
}

#Preview("Person Home • Day") {
    PersonHomeView.previewScreen(hour: 12, owlXP: 0)
}

#Preview("Person Home • Sunset") {
    PersonHomeView.previewScreen(hour: 18, owlXP: 0)
}

#Preview("Person Home • Night") {
    PersonHomeView.previewScreen(hour: 22, owlXP: 0)
}

#Preview("Owl Stage 0") {
    PersonHomeView.previewScreen(hour: 12, owlXP: 0)
}

#Preview("Owl Stage 1") {
    PersonHomeView.previewScreen(hour: 12, owlXP: 100)
}

#Preview("Owl Stage 2") {
    PersonHomeView.previewScreen(hour: 12, owlXP: 500)
}

#Preview("Owl Stage 3") {
    PersonHomeView.previewScreen(hour: 12, owlXP: 1000)
}

private extension PersonHomeView {
    @MainActor
    static func previewAppState(owlXP: Int) -> AppState {
        let state = AppState()
        state.appMode = .person
        state.isOnboardingComplete = true
        state.owlName = "ねね"
        state.owlXP = owlXP
        state.owlStage = 2
        return state
    }

    @MainActor
    static func previewScreen(hour: Int, owlXP: Int) -> some View {
        PersonHomeView(
            viewModel: .previewHomeState(now: previewDate(hour: hour)),
            loadsEventsOnTask: false,
            previewHour: hour
        )
        .environment(previewAppState(owlXP: owlXP))
    }

    static func previewDate(hour: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}

private extension PersonHomeViewModel {
    @MainActor
    static func previewHomeState(now: Date = Date()) -> PersonHomeViewModel {
        let viewModel = PersonHomeViewModel()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        viewModel.events = [
            AlarmEvent(
                title: "📌 カフェ",
                fireDate: now,
                eventEmoji: "📌",
                isToDo: true
            ),
            AlarmEvent(
                title: "🛒 買い物",
                fireDate: now,
                eventEmoji: "🛒",
                isToDo: true
            ),
            AlarmEvent(
                title: "眠りクリニック",
                fireDate: now.addingTimeInterval(15 * 60),
                preNotificationMinutes: 15,
                eventEmoji: "📌",
                completionStatus: .completed
            )
        ]
        viewModel.upcomingEvents = [
            AlarmEvent(
                title: "病院",
                fireDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow) ?? tomorrow,
                preNotificationMinutes: 15,
                eventEmoji: "📌"
            ),
            AlarmEvent(
                title: "家族と電話",
                fireDate: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: tomorrow) ?? tomorrow,
                preNotificationMinutes: 10,
                eventEmoji: "☎️"
            )
        ]
        viewModel.owlState = .sleepy
        viewModel.updateScreenHeightIfNeeded(844)
        return viewModel
    }
}
