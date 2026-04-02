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
    @State private var showDismissMessage = false
    @State private var isSkipped = false
    @State private var isUndone = false
    // アニメーション状態
    @State private var appeared = false
    @State private var bubbleBounce = false
    @State private var ripplePulse = false
    // スキップセクション（5秒後に表示）
    @State private var showSkipSection = false

    // SOSバナー用状態
    @State private var showSuccessBanner = false
    @State private var showErrorBanner = false
    @State private var errorMessage = ""
    // バナー自動非表示タスク（ビュー破棄時にキャンセルするため参照を保持）
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

            if showDismissMessage {
                dismissView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                mainContent
                    .transition(.opacity)
            }
            
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
                notificationType: appState.notificationType,
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
            if newValue == nil && !showDismissMessage { onDismissed() }
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
        // 5秒後にスキップセクションを表示（View が消えると自動キャンセル）
        .task {
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeInOut(duration: 0.4)) { showSkipSection = true }
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
                // .foreground オプション付きのためアプリが前面に来る。ユーザーが手動で止める想定
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
        .animation(.spring(duration: 0.4), value: showDismissMessage)
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

            Spacer()

            // 停止ボタン + スキップセクション（下部）
            VStack(spacing: Spacing.sm) {
                stopButton
                if showSkipSection {
                    skipSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
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

    // MARK: - フクロウ + 波紋

    private var owlWithRipple: some View {
        ZStack {
            // 波紋（外側）ping
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 160, height: 160)
                .scaleEffect(ripplePulse ? 1.5 : 1.0)
                .opacity(ripplePulse ? 0.0 : 0.7)
            // 波紋（内側）pulse
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 130, height: 130)
                .scaleEffect(bubbleBounce ? 1.08 : 0.96)
            // フクロウ背景円
            Circle()
                .fill(Color.white)
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
            // フクロウ本体
            Image("OwlIcon")
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
            // タイミングバッジ
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

            // 予定タイトル
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

    // MARK: - 停止ボタン

    private var stopButton: some View {
        Button {
            let sosWasFired = viewModel.sosStatus != .idle
            isSkipped = false
            viewModel.dismiss()
            withAnimation(.spring(duration: 0.4)) {
                showDismissMessage = true
            }
            ReviewManager.shared.recordCompletionAndRequestIfNeeded(isSOSFired: sosWasFired)
            // P-9-13: UIは3秒で自動クローズ。Undoは30秒バックグラウンドで継続
            Task {
                try? await Task.sleep(for: .seconds(3))
                if !isUndone { onDismissed() }
            }
        } label: {
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
        }
        .buttonStyle(.plain)
    }

    // MARK: - スキップセクション（5秒後に表示）

    private var skipSection: some View {
        let snoozeCount = viewModel.activeAlarm?.snoozeCount ?? 0

        return VStack(spacing: Spacing.sm) {
            // スヌーズボタン（最大3回まで。P-2-2/P-9-15）
            // P-2-3: 5秒間は透明プレースホルダーとして空間確保
            if snoozeCount < 3 {
                Button {
                    viewModel.snooze()
                    onDismissed()
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text("⏱️")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snoozeCount == 2
                                 ? "30分後にまた教えて（最後の1回）"
                                 : "30分後にまた教えて")
                                .font(.callout.weight(.medium))
                            if snoozeCount == 2 {
                                Text("次はパスか完了を選んでね")
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
                // スヌーズ上限到達メッセージ（P-9-15）
                VStack(spacing: 6) {
                    Text("🦉 何度もお知らせしたよ。今日は無理せず「今回はパス」にしてね")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }

            // スキップボタン
            Button {
                isSkipped = true
                viewModel.skip()
                withAnimation(.spring(duration: 0.4)) {
                    showDismissMessage = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    onDismissed()
                }
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

    // MARK: - 停止後の画面（おつかれさまです）

    private var dismissView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // フクロウ + 吹き出し
                ZStack(alignment: .topTrailing) {
                    Image("OwlIcon")
                        .resizable().scaledToFit()
                        .frame(width: 120, height: 120)

                    // オレンジ吹き出し
                    VStack(alignment: .leading, spacing: 2) {
                        Text("おつかれさまです！")
                            .font(.caption.weight(.bold))
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.95, green: 0.60, blue: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(red: 0.95, green: 0.60, blue: 0.15))
                            .rotationEffect(.degrees(30))
                            .offset(x: 8, y: 7)
                    }
                    .offset(x: 80, y: -12)
                }
                .frame(height: 120)
                .padding(.trailing, 80)

                // メッセージカード
                VStack(spacing: Spacing.md) {
                    // メインメッセージ
                    VStack(spacing: Spacing.md) {
                        Text(isSkipped ? "ゆっくり休んでね" : "よくできました！")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(isSkipped
                             ? "「\(pendingAlarm.title)」\n無理せず、今日は休みましょう 🍵"
                             : "「\(pendingAlarm.title)」\nそろそろ準備を始めましょう！")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    // XPバッジ（完了時のみ、P-2-1）
                    if !isSkipped {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("+10ポイント！")
                                .font(.callout.weight(.bold))
                                .foregroundStyle(Color.owlAmber)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.owlAmber.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    // Undoボタン（P-2-1/P-9-13）
                    if !isUndone {
                        Button {
                            viewModel.undoCompletion(alarm: pendingAlarm)
                            pendingAlarm = viewModel.activeAlarm ?? pendingAlarm
                            isUndone = false
                            isSkipped = false
                            showSkipSection = true
                            withAnimation(.spring(duration: 0.35)) {
                                showDismissMessage = false
                            }
                        } label: {
                            Text("↩ 間違えたので取り消す")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                    }

                    // 閉じるボタン（P-9-13: 即座に閉じられる）
                    Button {
                        onDismissed()
                    } label: {
                        Text("閉じる")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.owlAmber)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 14, y: 5)
                .padding(.horizontal, Spacing.lg)
            }

            Spacer()
        }
    }
    
    // MARK: - Helper UIs
    
    private func hideBannersAfterDelay() {
        // レビュー指摘: 非構造化Taskはビュー破棄後も生き続けタスクリークになる。
        // タスク参照を保持し、直前のタスクをキャンセルしてから新しいタスクを起動する。
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
