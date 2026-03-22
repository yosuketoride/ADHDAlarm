import SwiftUI
import MessageUI

/// 全画面アラーム鳴動画面
/// AlarmKit経由で起動、またはオンボーディングのテストアラームとして使用
struct RingingView: View {
    @State private var viewModel: RingingViewModel
    @Environment(AppState.self) private var appState
    /// アラームを止めた後に画面を閉じるコールバック
    var onDismissed: () -> Void = {}

    init(alarm: AlarmEvent, onDismissed: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: RingingViewModel())
        self.onDismissed = onDismissed
        // initでは直接セットできないため、onAppearで設定する
        _pendingAlarm = State(initialValue: alarm)
    }

    @State private var pendingAlarm: AlarmEvent
    @State private var isVisible = false
    @State private var showDismissMessage = false
    @State private var showSOSMessage = false

    var body: some View {
        ZStack {
            // 背景: 深い黒（集中させる）
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // カウントダウン（中央・最大サイズ・タイトルは内部に表示するため上部の重複テキストは不要）
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    countdownView(at: context.date)
                }

                Spacer()

                if showDismissMessage {
                    // 停止後メッセージ（中央・フクロウ付き）
                    VStack(spacing: 24) {
                        Spacer()
                        Text("🦉")
                            .font(.system(size: 80))
                        Text("おつかれさまです！")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("「\(viewModel.activeAlarm?.title ?? "ご予定")」\nそろそろ出発しましょう！")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                        Spacer()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } else {
                    // 停止ボタン（大きく・余白たっぷり・高齢者対応）
                    Button {
                        viewModel.dismiss()
                        showDismissMessage = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            onDismissed()
                        }
                    } label: {
                        Label("とめる", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.large(background: .green))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 56)
                }
            }
        }
        .onAppear {
            viewModel.activeAlarm = pendingAlarm
            viewModel.configure(
                notificationType: appState.notificationType,
                audioOutputMode: appState.audioOutputMode,
                sosContactPhone: appState.subscriptionTier == .pro ? appState.sosContactPhone : nil
            )
            viewModel.startAudioPlayback()
            withAnimation(.easeIn(duration: 0.4)) {
                isVisible = true
            }
        }
        .onChange(of: viewModel.activeAlarm) { _, newValue in
            // アラームがnilになった（AlarmKit側で停止された）場合のみ閉じる
            if newValue == nil && !showDismissMessage {
                onDismissed()
            }
        }
        // エスカレーション: 5分無応答でSOS iMessage を起動する
        .onChange(of: viewModel.shouldSendSOS) { _, shouldSend in
            guard shouldSend,
                  MFMessageComposeViewController.canSendText(),
                  viewModel.sosContactPhone != nil else { return }
            showSOSMessage = true
        }
        .sheet(isPresented: $showSOSMessage) {
            if let phone = viewModel.sosContactPhone,
               let alarm = viewModel.activeAlarm {
                MessageComposeView(
                    recipients: [phone],
                    body: "【こえメモ】\(alarm.title)のアラームに5分間応答がありません。ご確認をお願いします。",
                    onDismiss: { _ in
                        showSOSMessage = false
                        viewModel.shouldSendSOS = false
                    }
                )
                .ignoresSafeArea()
            }
        }
        // バックボタン・スワイプ離脱を防ぐ（アラームは必ず操作で止める）
        .interactiveDismissDisabled(!showSOSMessage)
        .statusBarHidden(true)
    }

    // MARK: - カウントダウン表示

    @ViewBuilder
    private func countdownView(at now: Date) -> some View {
        if let alarm = viewModel.activeAlarm {
            let preMin = alarm.preNotificationMinutes
            // 事前通知アラームの残り時間 = 予定時刻 - 現在時刻（マイナスなら0）
            let secondsToEvent = max(0, alarm.fireDate.timeIntervalSince(now))
            let minutesToEvent = Int(ceil(secondsToEvent / 60.0))

            if preMin == 0 {
                // ジャスト（予定時刻ぴったり）で発火したアラーム
                VStack(spacing: 12) {
                    Text(alarm.title)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 24)
                    Text("の時間です！")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else if minutesToEvent == 0 {
                // カウントダウンが0になった（予定時刻を過ぎた）
                VStack(spacing: 12) {
                    Text("時間です！")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(alarm.title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                // 事前通知アラーム: カウントダウン数字を超大きく表示
                VStack(spacing: 4) {
                    Text("あと")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    Text("\(minutesToEvent)")
                        .font(.system(size: 140, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: minutesToEvent)

                    Text("分で")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 4)

                    Text("\(alarm.title)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Text("です")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}

#Preview {
    RingingView(alarm: AlarmEvent(
        title: "カフェで待ち合わせ",
        fireDate: Date().addingTimeInterval(900),
        preNotificationMinutes: 15
    ))
}
