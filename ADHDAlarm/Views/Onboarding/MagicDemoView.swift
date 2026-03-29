import SwiftUI
import AVFoundation

/// オンボーディング: Aha体験（マナーモード貫通デモ）
struct MagicDemoView: View {
    let hapticOnly: Bool

    @Environment(AppState.self) private var appState
    @State private var countdown = 3
    @State private var isCounting = false
    @State private var showRinging = false
    @State private var showSoundCheckDialog = false
    @State private var showLowVolumeNote = false
    @State private var showHapticFollowUp = false
    @State private var timer: Timer?
    @State private var demoAlarm = AlarmEvent(
        title: "15時からカフェで待ち合わせ",
        fireDate: Date().addingTimeInterval(60),
        preNotificationMinutes: 0
    )

    private let voiceGenerator = VoiceFileGenerator()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("OwlIcon")
                .resizable().scaledToFit()
                .frame(width: 120, height: 120)

            Spacer().frame(height: Spacing.xl)

            if showHapticFollowUp {
                hapticFollowUpSection
            } else if isCounting {
                countingSection
            } else if hapticOnly {
                hapticStandbySection
            } else {
                normalDemoSection
            }
        }
        .navigationBarBackButtonHidden()
        .fullScreenCover(isPresented: $showRinging) {
            RingingView(alarm: demoAlarm) {
                showRinging = false
                // P-6-3: 0.5秒後にダイアログ表示
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    showSoundCheckDialog = true
                }
            }
        }
        .confirmationDialog(
            "♪ 音は無事に鳴りましたか？",
            isPresented: $showSoundCheckDialog,
            titleVisibility: .visible
        ) {
            Button("鳴った！") { navigateToWidgetGuide() }
            Button("鳴らなかった") { openNotificationSettings() }
        }
        .onDisappear { timer?.invalidate() }
        .task {
            if hapticOnly { await runHapticDemo() }
        }
    }

    // MARK: - コンテンツセクション

    private var normalDemoSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.sm) {
                Text("本当にマナーモードでも\n鳴るか試してみよう！")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("スマホをマナーモードにして\n下のボタンを押してみてください")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.md)

            Spacer().frame(height: Spacing.sm)

            Text("🔊 音量を上げてから押してね")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: Spacing.md) {
                Button("🔔 3秒後にアラームを鳴らす") { startDemo() }
                    .frame(maxWidth: .infinity)
                    .frame(height: ComponentSize.primary)
                    .background(Color.owlAmber)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

                Button("あとで試す →") { navigateToWidgetGuide() }
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: ComponentSize.small)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    private var hapticStandbySection: some View {
        VStack(spacing: Spacing.sm) {
            Text("振動でお知らせします")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
            Spacer()
        }
    }

    private var countingSection: some View {
        VStack(spacing: Spacing.sm) {
            if showLowVolumeNote {
                Text("マナーモードでも鳴るんですよ！\nAlarmKitは音量設定を無視します。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)
            }

            Text("あと\(countdown)秒…")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(Color.owlAmber)
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring, value: countdown)

            Text("スマホをしっかり持ってね！")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    private var hapticFollowUpSection: some View {
        VStack(spacing: 0) {
            // P-6-4: Hapticデモのフォローアップテキスト
            VStack(spacing: Spacing.sm) {
                Text("今は振動だけでしたが、")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("本当はマナーモードでも\n必ず音が鳴るアラームです。\n明日を楽しみにしていてください！")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            Button("わかった！") { navigateToWidgetGuide() }
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.primary)
                .background(Color.owlAmber)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - デモロジック

    private func startDemo() {
        let session = AVAudioSession.sharedInstance()
        let outputVolume = session.outputVolume
        let hasOutputDevice = !session.currentRoute.outputs.isEmpty

        // フロー③: 出力デバイスなし → Hapticのみ
        guard hasOutputDevice else {
            Task { await runHapticDemo() }
            return
        }
        // フロー②: 音量0.1以下 → 注記を出してもデモ続行
        if outputVolume <= 0.1 {
            withAnimation { showLowVolumeNote = true }
        }

        // 音声ファイル事前生成
        Task {
            if let url = try? await voiceGenerator.generateAudio(
                text: VoiceFileGenerator.speechText(for: demoAlarm),
                character: .femaleConcierge,
                alarmID: demoAlarm.id
            ) {
                demoAlarm.voiceFileName = url.lastPathComponent
            }
        }

        // カウントダウン開始
        countdown = 3
        isCounting = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if countdown > 1 {
                countdown -= 1
            } else {
                t.invalidate()
                timer = nil
                showRinging = true
            }
        }
    }

    /// Hapticのみのデモ（出力デバイスなし or hapticOnly=true）
    private func runHapticDemo() async {
        countdown = 3
        isCounting = true
        for i in stride(from: 3, through: 1, by: -1) {
            countdown = i
            try? await Task.sleep(for: .seconds(1))
        }
        // 振動3回
        for _ in 0..<3 {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            try? await Task.sleep(for: .milliseconds(400))
        }
        isCounting = false
        withAnimation { showHapticFollowUp = true }
    }

    private func navigateToWidgetGuide() {
        appState.onboardingPath.append(OnboardingDestination.widgetGuide)
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
        navigateToWidgetGuide()
    }
}
