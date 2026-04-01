import SwiftUI
import UIKit

/// 当事者モードのホーム画面
/// タブレス・1画面集約・ストレス排除設計
struct PersonHomeView: View {
    @State private var viewModel = PersonHomeViewModel()
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // フクロウ首傾けアニメ用
    @State private var owlNeckTilt: Double = 0
    // レビュー指摘: confirmationDialog は親に1つだけ配置する（EventRow側から移動）
    @State private var eventToDelete: AlarmEvent?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // レイヤー1（最背面）: 時間帯グラデーション背景
            TimeOfDayBackground()
                .ignoresSafeArea()

            // レイヤー2: メインコンテンツ（スクロール可能）
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    owlSection
                        .padding(.top, Spacing.xs)
                    countdownSection
                    eventListSection
                        .padding(.top, Spacing.lg)
                    tomorrowSection
                    // FABの高さ分の余白（被り防止）
                    Spacer().frame(height: ComponentSize.fab + Spacing.xl)
                }
            }
            .refreshable { await viewModel.performManualSync() }

            // レイヤー3（最前面）: マイクFAB
            micFAB
                .padding(.trailing, Spacing.md)
                .padding(.bottom, Spacing.md)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        viewModel.updateScreenHeightIfNeeded(proxy.size.height)
                    }
                    .onChange(of: proxy.size.height) { _, newHeight in
                        viewModel.updateScreenHeightIfNeeded(newHeight)
                    }
            }
        }
        // Toast（シェイク等の通知）
        .overlay(alignment: .top) {
            if let msg = viewModel.confirmationMessage {
                toastBanner(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, Spacing.md)
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 0) {
                Button {
                    Task { await viewModel.performManualSync() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: IconSize.sm))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, height: 60)
                }

                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: IconSize.md))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, height: 60)
                }
            }
            .padding(.top, Spacing.sm)
            .padding(.trailing, Spacing.lg)
        }
        // マイク入力シート
        .sheet(isPresented: $viewModel.showMicSheet) {
            MicrophoneInputView(viewModel: InputViewModel(appState: appState))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // 設定シート
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: SettingsViewModel(appState: appState))
        }
        // テキスト手動入力シート（P-1-3）
        // onDismiss: confirmAndSchedule()完走後にdismissされるため、ここでloadEventsすれば確実に反映される
        .sheet(isPresented: $viewModel.showManualInput, onDismiss: {
            Task { await viewModel.loadEvents() }
        }) {
            NavigationStack {
                PersonManualInputView(viewModel: InputViewModel(appState: appState))
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
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.confirmationMessage != nil)
        .animation(.spring(duration: 0.3), value: viewModel.pendingDelete != nil)
        .onShake { viewModel.handleOwlShake() }
        .task {
            viewModel.bindAppStateIfNeeded(appState)
            await viewModel.loadEvents()
        }
        .confirmationDialog(
            "「\(eventToDelete?.title ?? "")」を削除しますか？（iPhoneのカレンダーからも消えます）",
            isPresented: Binding(get: { eventToDelete != nil }, set: { if !$0 { eventToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                if let alarm = eventToDelete {
                    Task { await viewModel.deleteEvent(alarm) }
                }
                eventToDelete = nil
            }
            Button("やめる", role: .cancel) { eventToDelete = nil }
        }
    }

    // MARK: - フクロウセクション

    private var owlSection: some View {
        // 吹き出し（左）＋ フクロウ（右）を横並びに配置
        HStack(alignment: .center, spacing: Spacing.sm) {
            // 左: 吹き出し（フクロウの左上あたり）
            greetingBubble
                .frame(maxWidth: .infinity, alignment: .trailing)

            // 右: フクロウ本体
            owlImage
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(owlNeckTilt))
                .onTapGesture { handleOwlTap() }
                .onLongPressGesture(minimumDuration: 0.8) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.showSettings = true
                }
                // ⚙️ボタンと重ならないよう右端に余白
                .padding(.trailing, Spacing.xl + Spacing.lg)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - 吹き出しあいさつ（青・白文字・右向きテール）

    private var greetingBubble: some View {
        HStack(spacing: 0) {
            // 本文バブル（青背景・白文字）
            Text(viewModel.greeting)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.statusPending)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .shadow(color: Color.statusPending.opacity(0.3), radius: 6, x: 0, y: 3)

            // 右向き三角（フクロウを指す）
            BubbleTailRight()
                .fill(Color.statusPending)
                .frame(width: 10, height: 18)
        }
    }

    // MARK: - 吹き出し三角シェイプ（右向き）

    private struct BubbleTailRight: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))    // 左上
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) // 右中央（先端）
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // 左下
            p.closeSubpath()
            return p
        }
    }

    @ViewBuilder
    private var owlImage: some View {
        // XPに応じてふくろうのステージアセットを切り替える（owl_stage0〜3）
        // アセットが存在しない場合は OwlIcon にフォールバック
        let imageName = UIImage(named: viewModel.owlImageName) != nil ? viewModel.owlImageName : "OwlIcon"
        Image(imageName)
            .resizable()
            .scaledToFit()
            .saturation(viewModel.owlState == .sleepy ? 0.4 : 1.0)
            .scaleEffect(viewModel.owlState == .happy ? 1.1 : 1.0)
            .animation(.spring(duration: 0.4, bounce: 0.5), value: viewModel.owlState)
    }

    // MARK: - カウントダウンセクション

    @ViewBuilder
    private var countdownSection: some View {
        if let next = viewModel.nextAlarm {
            let minutes = next.fireDate.timeIntervalSinceNow / 60
            VStack(spacing: Spacing.sm) {
                if minutes < 60 {
                    // 60分未満: 円形カウントダウン
                    circularCountdown(minutes: Int(minutes), alarm: next)
                } else {
                    // 60分以上: シンプルテキスト表示
                    nextEventText(alarm: next)
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func circularCountdown(minutes: Int, alarm: AlarmEvent) -> some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                // 背景リング
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                // 進捗リング（10分未満: 赤+パルス）
                Circle()
                    .trim(from: 0, to: min(1.0, CGFloat(minutes) / 60.0))
                    .stroke(
                        minutes < 10 ? Color.statusDanger : Color.owlAmber,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                    .animation(.easeInOut(duration: 1.0), value: minutes)
                // 中央テキスト
                VStack(spacing: 2) {
                    Text("あと")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(minutes)分")
                        .font(.title2.bold())
                        .foregroundStyle(minutes < 10 ? Color.statusDanger : Color.primary)
                        .monospacedDigit()
                }
            }
            Text(alarm.title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
    }

    private func nextEventText(alarm: AlarmEvent) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(alarm.eventEmoji ?? "📌")
                .font(.system(size: IconSize.lg))
            VStack(alignment: .leading, spacing: 2) {
                Text("次は")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(alarm.fireDate.japaneseTimeString) \(alarm.title)")
                    .font(.body.weight(.medium))
            }
        }
        .padding(Spacing.md)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - 予定リストセクション

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // セクションヘッダー
            Text("── 今日のご予定 ──")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.lg)

            // 未完了の予定がゼロの場合に空状態メッセージを表示
            // （完了済みが残っていても未完了がゼロなら空状態）
            if viewModel.visibleEvents.isEmpty {
                emptyStateView
            } else {
                // 未完了の予定（折りたたみ）
                ForEach(viewModel.visibleEvents) { alarm in
                    EventRow(alarm: alarm) {
                        eventToDelete = alarm
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // 折りたたみボタン
                if viewModel.hiddenEventCount > 0 && !viewModel.isEventListExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.isEventListExpanded = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("＋ 残り\(viewModel.hiddenEventCount)件を表示")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(minHeight: ComponentSize.small)
                    }
                    .padding(.horizontal, Spacing.md)
                }

                if viewModel.isEventListExpanded && viewModel.hiddenEventCount == 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.isEventListExpanded = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("折りたたむ")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(minHeight: ComponentSize.small)
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // P-1-4: 未完了が2件以下のときは追加CTAを表示
                if viewModel.visibleEvents.count <= 2 {
                    shortcutButtonsRow(
                        voiceLabel: "🎤 予定を追加",
                        textLabel: "✏️ テキストで追加",
                        font: .footnote
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                    .frame(minHeight: 44)
                }

            }

            // 完了済み予定（greyout・未完了リストの外に独立配置）
            // visibleEvents が空でも完了済みは常に表示する
            if !viewModel.completedTodayEvents.isEmpty {
                ForEach(viewModel.completedTodayEvents) { alarm in
                    EventRow(alarm: alarm) {
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
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xl)

            // CTA（P-1-4: マイクとテキスト両方表示）
            shortcutButtonsRow(
                voiceLabel: info.ctaLabel,
                textLabel: "✏️ テキストで追加",
                font: .subheadline
            )

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

    // MARK: - 明日の予定セクション

    @ViewBuilder
    private var tomorrowSection: some View {
        if !viewModel.tomorrowEvents.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("─── ここから明日以降 ───")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)

                ForEach(viewModel.tomorrowEvents) { alarm in
                    EventRow(alarm: alarm, showDate: true) {
                        eventToDelete = alarm
                    }
                    .padding(.horizontal, Spacing.md)
                    .opacity(0.6)
                }

                // 📅 カレンダーで先を見るリンク（P-1-8）
                if let url = URL(string: "calshow://") {
                    Link(destination: url) {
                        Text("📅 カレンダーで先の予定を確認する")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }

    // MARK: - マイクFAB

    private var micFAB: some View {
        Button {
            viewModel.showMicSheet = true
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: "mic.fill")
                    .font(.system(size: IconSize.md, weight: .bold))
                if !shouldUseCompactFABLabel {
                    Text("予定を追加")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(.black)
            .frame(width: ComponentSize.fab, height: ComponentSize.fab)
            .background(Color.owlAmber)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.fab))
            .contentShape(Circle())
            .shadow(color: Color.owlAmber.opacity(0.4), radius: 8, y: 4)
        }
        .accessibilityLabel("予定を追加")
    }

    private var shouldStackShortcutButtons: Bool {
        dynamicTypeSize >= .xxxLarge
    }

    private var shouldUseCompactFABLabel: Bool {
        dynamicTypeSize >= .xLarge
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
                    viewModel.showMicSheet = true
                }
                shortcutButton(title: textLabel, font: font) {
                    viewModel.showManualInput = true
                }
            }
        } else {
            HStack(spacing: Spacing.md) {
                shortcutButton(title: voiceLabel, font: font) {
                    viewModel.showMicSheet = true
                }

                Text("｜")
                    .font(font)
                    .foregroundStyle(.tertiary)

                shortcutButton(title: textLabel, font: font) {
                    viewModel.showManualInput = true
                }
            }
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
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
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
}
