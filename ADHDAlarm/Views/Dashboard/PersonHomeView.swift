import SwiftUI

/// 当事者モードのホーム画面
/// タブレス・1画面集約・ストレス排除設計
struct PersonHomeView: View {
    @State private var viewModel = PersonHomeViewModel()
    @Environment(AppState.self) private var appState

    // フクロウ首傾けアニメ用
    @State private var owlNeckTilt: Double = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // レイヤー1（最背面）: 時間帯グラデーション背景
            TimeOfDayBackground()
                .ignoresSafeArea()

            // レイヤー2: メインコンテンツ（スクロール可能）
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    owlSection
                        .padding(.top, Spacing.lg)
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
        // Toast（シェイク等の通知）
        .overlay(alignment: .top) {
            if let msg = viewModel.confirmationMessage {
                toastBanner(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, Spacing.md)
            }
        }
        // マイク入力シート
        .sheet(isPresented: $viewModel.showMicSheet) {
            MicrophoneInputView(viewModel: InputViewModel(appState: appState))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // 設定シート
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: SettingsViewModel(appState: appState))
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
        .task { await viewModel.loadEvents() }
    }

    // MARK: - フクロウセクション

    private var owlSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .topTrailing) {
                // フクロウ本体
                owlImage
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(owlNeckTilt))
                    .onTapGesture { handleOwlTap() }
                    .onLongPressGesture(minimumDuration: 0.8) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.showSettings = true
                    }

                // ⚙️ ボタン（右上）
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: IconSize.md))
                        .foregroundStyle(.secondary)
                        .frame(width: ComponentSize.small, height: ComponentSize.small)
                }
                .offset(x: 24, y: -8)
            }
            .padding(.trailing, Spacing.xl)

            // あいさつ文
            Text(viewModel.greeting)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
    }

    @ViewBuilder
    private var owlImage: some View {
        // TODO: Phase 3 でふくろう進化ステージのアセット（owl_stage0〜3）に切り替える
        // 現在は OwlIcon アセットを状態に応じて変化させる
        let imageName = "OwlIcon"
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    // MARK: - 予定リストセクション

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // セクションヘッダー
            Text("── 今日のご予定 ──")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.lg)

            if viewModel.events.isEmpty {
                emptyStateView
            } else {
                // 未完了の予定（折りたたみ）
                ForEach(viewModel.visibleEvents) { alarm in
                    EventRow(alarm: alarm) {
                        Task { await viewModel.deleteEvent(alarm) }
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

                // 完了済み予定（グレーアウト）
                if !viewModel.completedTodayEvents.isEmpty {
                    ForEach(viewModel.completedTodayEvents) { alarm in
                        EventRow(alarm: alarm) {
                            Task { await viewModel.deleteEvent(alarm) }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
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

            // CTA（さりげない提案）
            Button {
                viewModel.showMicSheet = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(info.ctaLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: ComponentSize.small)
        }
        .padding(Spacing.lg)
    }

    // MARK: - 明日の予定セクション

    @ViewBuilder
    private var tomorrowSection: some View {
        if !viewModel.tomorrowEvents.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("─── ここから明日 ───")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)

                ForEach(viewModel.tomorrowEvents) { alarm in
                    EventRow(alarm: alarm, showDate: true) {
                        Task { await viewModel.deleteEvent(alarm) }
                    }
                    .padding(.horizontal, Spacing.md)
                    .opacity(0.6)
                }
            }
        }
    }

    // MARK: - マイクFAB

    private var micFAB: some View {
        Button {
            viewModel.showMicSheet = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: IconSize.md, weight: .bold))
                Text("予定を追加")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: ComponentSize.fab, height: ComponentSize.fab)
            .background(Color.owlAmber)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.fab))
            .shadow(color: Color.owlAmber.opacity(0.4), radius: 8, y: 4)
        }
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
