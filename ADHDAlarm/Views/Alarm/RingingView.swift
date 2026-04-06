import SwiftUI
import StoreKit

/// 全画面アラーム鳴動画面
/// AlarmKit経由で起動、またはオンボーディングのテストアラームとして使用
struct RingingView: View {
    @State private var viewModel: RingingViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onDismissed: () -> Void = {}

    init(alarm: AlarmEvent, onDismissed: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: RingingViewModel())
        self.onDismissed = onDismissed
        _pendingAlarm = State(initialValue: alarm)
    }

    @State private var pendingAlarm: AlarmEvent
    @State private var hasDismissed = false          // 二重呼び出し防止
    @State private var showSkipConfirmation = false  // スキップ確認ダイアログ
    // アニメーション状態
    @State private var appeared = false
    @State private var bubbleBounce = false
    @State private var ripplePulse = false

    // SOSバナー用状態
    @State private var showSuccessBanner = false
    @State private var showErrorBanner = false
    @State private var errorMessage = ""
    @State private var bannerHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // 暖かいグラデーション背景
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.90, blue: 0.88),
                    Color(red: 1.0,  green: 0.95, blue: 0.87),
                    Color(red: 1.0,  green: 0.98, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 装飾: 光のぼかし
            Circle()
                .fill(Color.yellow.opacity(0.35))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -100, y: -320)
                .ignoresSafeArea()
            Circle()
                .fill(Color(red: 1.0, green: 0.7, blue: 0.7).opacity(0.35))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 130, y: -160)
                .ignoresSafeArea()

            mainContent
                .transition(.opacity)

            // SOS状態バナー
            VStack {
                if showSuccessBanner {
                    sosBanner(isSuccess: true, message: "家族にLINE通知を送りました")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if showErrorBanner {
                    sosBanner(isSuccess: false, message: errorMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 40)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSuccessBanner)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showErrorBanner)
        }
        .onAppear {
            viewModel.activeAlarm = pendingAlarm
            viewModel.bindAppStateIfNeeded(appState)
            viewModel.configure(
                audioOutputMode: appState.audioOutputMode,
                sosPairingId: appState.sosPairingId,
                sosEscalationMinutes: appState.sosEscalationMinutes
            )
            viewModel.startAudioPlayback()
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { appeared = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.3)) {
                bubbleBounce = true
            }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(0.5)) {
                ripplePulse = true
            }
        }
        .onChange(of: viewModel.activeAlarm) { _, newValue in
            // VMがアラームをnilにした場合（外部からの停止など）も安全に閉じる
            if newValue == nil && !hasDismissed {
                hasDismissed = true
                onDismissed()
            }
        }
        .onChange(of: viewModel.sosStatus) { _, status in
            switch status {
            case .sent:
                showSuccessBanner = true
                hideBannersAfterDelay()
            case .failed(let msg):
                errorMessage = msg
                showErrorBanner = true
                hideBannersAfterDelay()
            default: break
            }
        }
        // スキップ確認ダイアログ
        .confirmationDialog(
            "今日はスキップしますか？",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("今日は休む", role: .destructive) {
                guard !hasDismissed else { return }
                hasDismissed = true
                viewModel.skip()
                let title = viewModel.activeAlarm?.title ?? ""
                ToastWindowManager.shared.show(ToastMessage(
                    text: title.isEmpty ? "ゆっくり休んでね 🍵" : "「\(title)」\nゆっくり休んでね 🍵",
                    style: .owlTip
                ))
                onDismissed()
            }
            Button("やっぱりやる", role: .cancel) {}
        }
        // バナーのボタンから届いたアクションを処理する
        .onReceive(NotificationCenter.default.publisher(
            for: ForegroundNotificationDelegate.alarmActionNotification
        )) { notification in
            guard let userInfo = notification.userInfo,
                  let actionID = userInfo[ForegroundNotificationDelegate.alarmActionIdentifierKey] as? String
            else { return }
            switch actionID {
            case Constants.Notification.actionDismiss:
                break
            case Constants.Notification.actionSnooze:
                viewModel.snooze()
            case Constants.Notification.actionSkip:
                viewModel.skip()
            default:
                break
            }
        }
        .onDisappear { bannerHideTask?.cancel() }
        .interactiveDismissDisabled()
        .statusBarHidden(true)
    }

    // MARK: - とめる処理（共通）

    private func performStop() {
        guard !hasDismissed else { return }
        hasDismissed = true
        let sosWasFired = viewModel.sosStatus != .idle
        viewModel.dismiss()
        ReviewManager.shared.recordCompletionAndRequestIfNeeded(isSOSFired: sosWasFired)
        ToastWindowManager.shared.show(ToastMessage(
            text: "よくできました！ ⭐️ +10ポイント",
            style: .owlTip
        ))
        onDismissed()
    }

    // MARK: - メイン画面

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // 吹き出し + フクロウ（上部）
            VStack(spacing: 0) {
                speechBubble
                    .offset(y: bubbleBounce ? -6 : 0)
                    .padding(.bottom, Spacing.md)
                owlWithRipple
            }
            .scaleEffect(appeared ? 1.0 : 0.8)
            .opacity(appeared ? 1.0 : 0)

            Spacer()

            // 予定詳細カード（中央）
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                eventCard(at: context.date)
            }
            .padding(.horizontal, Spacing.lg)
            .scaleEffect(appeared ? 1.0 : 0.9)
            .opacity(appeared ? 1.0 : 0)

            // 停止ゾーン：カード下から画面下端まで全体がタップで「とめる」
            // 寝ぼけていてもどこでも押せるよう、背景全体をタップ領域にする
            ZStack(alignment: .bottom) {
                // 背景全体のタップ領域
                Button(action: performStop) {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // 視覚的なボタン・スキップセクション（前面に重ねる）
                VStack(spacing: Spacing.sm) {
                    stopButtonLabel
                    skipSection
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 56)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 240)
            .opacity(appeared ? 1.0 : 0)
            .offset(y: appeared ? 0 : 20)
        }
    }

    // MARK: - 吹き出し

    private var speechBubble: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 5)

                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(red: 0.95, green: 0.60, blue: 0.15))
                    Text("時間です！")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            }

            // 吹き出しのしっぽ
            Triangle()
                .fill(Color.white)
                .frame(width: 28, height: 14)
                .shadow(color: .black.opacity(0.06), radius: 3, y: 3)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - フクロウ画像ヘルパー

    private func owlImageName(emotion: String) -> String {
        let stage: Int
        switch appState.owlXP {
        case 0..<100:    stage = 0
        case 100..<500:  stage = 1
        case 500..<1000: stage = 2
        default:         stage = 3
        }
        let name = "owl_stage\(stage)_\(emotion)"
        if UIImage(named: name) != nil { return name }
        let normal = "owl_stage\(stage)_normal"
        if UIImage(named: normal) != nil { return normal }
        return "OwlIcon"
    }

    // MARK: - フクロウ + 波紋

    private var owlWithRipple: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 160, height: 160)
                .scaleEffect(ripplePulse ? 1.5 : 1.0)
                .opacity(ripplePulse ? 0.0 : 0.7)
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 130, height: 130)
                .scaleEffect(bubbleBounce ? 1.08 : 0.96)
            Circle()
                .fill(Color.white)
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
            Image(owlImageName(emotion: "surprised"))
                .resizable().scaledToFit()
                .frame(width: 88, height: 88)
        }
        .frame(width: 160, height: 160)
    }

    // MARK: - 予定詳細カード

    @ViewBuilder
    private func eventCard(at now: Date) -> some View {
        if let alarm = viewModel.activeAlarm {
            let secondsToEvent = max(0, alarm.fireDate.timeIntervalSince(now))
            let minutesToEvent = Int(ceil(secondsToEvent / 60.0))

            if dynamicTypeSize >= .accessibility3 {
                largeTypeEventCard(alarm: alarm, minutesToEvent: minutesToEvent)
            } else {
                standardEventCard(alarm: alarm, minutesToEvent: minutesToEvent)
            }
        }
    }

    private func standardEventCard(alarm: AlarmEvent, minutesToEvent: Int) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(Color(red: 0.95, green: 0.60, blue: 0.15))
                    .frame(width: 8, height: 8)
                    .opacity(bubbleBounce ? 1.0 : 0.4)
                if alarm.preNotificationMinutes == 0 {
                    Text("ちょうど今の時間です")
                } else if minutesToEvent == 0 {
                    Text("予定の時間を過ぎました")
                } else {
                    Text("あと\(minutesToEvent)分で予定です")
                }
            }
            .font(.callout.weight(.bold))
            .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.0))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color(red: 1.0, green: 0.93, blue: 0.72))
            .clipShape(Capsule())

            Text(alarm.title)
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 14, y: 5)
    }

    private func largeTypeEventCard(alarm: AlarmEvent, minutesToEvent: Int) -> some View {
        VStack(spacing: Spacing.md) {
            if alarm.preNotificationMinutes == 0 {
                Text("今")
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            } else {
                Text("\(max(minutesToEvent, 0))")
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                Text("分")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(alarm.preNotificationMinutes == 0 ? "予定の時間です" : "あと\(max(minutesToEvent, 0))分で予定です")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)

            Text(alarm.title)
                .font(.title2.weight(.black))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 14, y: 5)
    }

    // MARK: - 停止ボタン（見た目のみ・タップは背景の大きな領域で受ける）

    private var stopButtonLabel: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .bold))
            Text("とめる")
                .font(.title2.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: ComponentSize.actionGiant)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.78, blue: 0.42),
                    Color(red: 0.12, green: 0.65, blue: 0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color(red: 0.12, green: 0.65, blue: 0.30).opacity(0.5), radius: 14, y: 7)
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        // タップ判定を無効化して背景の大きな領域に委譲する
        .allowsHitTesting(false)
    }

    // MARK: - スキップセクション（常時表示・確認ダイアログあり）

    private var skipSection: some View {
        VStack(spacing: Spacing.sm) {
            // スヌーズボタン（最大3回まで）
            if viewModel.canSnooze {
                Button {
                    viewModel.snooze()
                    onDismissed()
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text("⏱️")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.snoozeButtonTitle)
                                .font(.callout.weight(.medium))
                            if let helper = viewModel.snoozeHelperMessage {
                                Text(helper)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: ComponentSize.small)
                    .background(Color(.secondarySystemBackground).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 6) {
                    Text(viewModel.snoozeLimitMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if viewModel.shouldShowSnoozeLimitArrow {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
            }

            // スキップボタン（確認ダイアログを経由する）
            Button {
                showSkipConfirmation = true
            } label: {
                Text("今日は休む（スキップ）")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ComponentSize.small)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper UIs

    private func hideBannersAfterDelay() {
        bannerHideTask?.cancel()
        bannerHideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation {
                showSuccessBanner = false
                showErrorBanner = false
            }
        }
    }

    private func sosBanner(isSuccess: Bool, message: String) -> some View {
        HStack(spacing: CornerRadius.md) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSuccess ? .green : .orange)
                .font(.title3)
            Text(message)
                .font(.callout.bold())
                .foregroundColor(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - 吹き出しのしっぽ

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    RingingView(alarm: AlarmEvent(
        title: "カフェで待ち合わせ",
        fireDate: Date().addingTimeInterval(900),
        preNotificationMinutes: 15
    ))
}
