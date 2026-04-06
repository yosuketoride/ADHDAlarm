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
    // レビュー指摘: Timer はTask.sleep(async/await)と混在させず Task に統一する
    @State private var countdownTask: Task<Void, Never>?
    @State private var demoAlarm = AlarmEvent(
        title: "15時からカフェで待ち合わせ",
        fireDate: Date().addingTimeInterval(60),
        preNotificationMinutes: 0
    )

    private let voiceGenerator = VoiceFileGenerator()
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("owl_stage0_normal")
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
        .onDisappear { countdownTask?.cancel() }
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
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ComponentSize.small)
                    .contentShape(Rectangle())
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

            Button("わかった！🦉") { navigateToWidgetGuide() }
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
        // ⚠️⚠️⚠️ マナーモード検知の制限について（実装者必読）⚠️⚠️⚠️ P-9-8
        //
        // iOS には公開APIでマナーモード状態を確実に取得する方法が存在しない。
        // AVAudioSession.outputVolume は以下の場合に誤判定する:
        //   - ユーザーが意図的に音量を0にしている（マナーモードではない）
        //   - Bluetooth接続時に音量が自動変動する
        //   - アクセシビリティ設定で音量動作が変わっている
        //
        // 本実装は「警告を出す」ためのヒューリスティックであり、
        // 「マナーモードを確実に検知する」ものではない。
        // この検知は不確実であり AlarmKit の動作には影響しない。
        // AlarmKit がマナーモードを貫通して鳴ることが本アプリの根幹であるため、
        // この検知ロジックに依存した「アラームが鳴らない」ケースを作ってはいけない。

        // フロー②: 音量0.1以下 → 注記を出してもデモ続行（誤判定の可能性あり）
        if outputVolume <= 0.1 {
            withAnimation { showLowVolumeNote = true }
        }

        // 音声ファイル事前生成
        Task {
            if let url = try? await voiceGenerator.generateAudio(
                text: VoiceFileGenerator.speechText(for: demoAlarm),
                character: .femaleConcierge,
                alarmID: demoAlarm.id,
                eventTitle: demoAlarm.title
            ) {
                demoAlarm.voiceFileName = url.lastPathComponent
            }
        }

        // カウントダウン開始（Timer→Taskに統一。ビュー破棄時にcountdownTask?.cancel()で停止）
        countdown = 3
        isCounting = true
        countdownTask?.cancel()
        countdownTask = Task {
            for i in stride(from: 3, through: 1, by: -1) {
                countdown = i
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
            }
            isCounting = false
            showRinging = true
        }
    }

    /// Hapticのみのデモ（出力デバイスなし or hapticOnly=true）
    private func runHapticDemo() async {
        // prepare() を先に呼んでTaptic Engineを起動状態にする（呼ばないと最初の振動が不発になる）
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()

        countdown = 3
        isCounting = true
        for i in stride(from: 3, through: 1, by: -1) {
            countdown = i
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
        }
        // 振動3回（毎回 prepare して取りこぼしを減らす）
        try? await Task.sleep(for: .milliseconds(120))
        for index in 0..<3 {
            generator.prepare()
            generator.impactOccurred()
            if index < 2 {
                try? await Task.sleep(for: .milliseconds(550))
            }
        }
        isCounting = false
        withAnimation { showHapticFollowUp = true }
    }

    private func navigateToWidgetGuide() {
        appState.onboardingPath.append(OnboardingDestination.widgetGuide)
    }

    private func openNotificationSettings() {
        // レビュー指摘: UIApplication.shared.open はUIKit依存。@Environment(\.openURL) を使う。
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
        navigateToWidgetGuide()
    }
}
