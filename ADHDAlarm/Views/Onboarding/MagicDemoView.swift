import SwiftUI

/// オンボーディング Step 2: Magic Presentation（Aha! Moment）
/// AlarmKit権限取得前なので、タイマーでRingingViewを起動して体験させる
struct MagicDemoView: View {
    @State private var countdown = 0
    @State private var isCounting = false
    @State private var showRinging = false
    @State private var timer: Timer?
    @State private var demoAlarm = AlarmEvent(
        title: "15時から友達とカフェ",
        fireDate: Date().addingTimeInterval(3)
    )

    private let voiceGenerator = VoiceFileGenerator()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, isActive: isCounting)

                    Text("今すぐ体験してみましょう")
                        .font(.title.weight(.bold))

                    Text("マナーモードをオンにしたまま\nボタンを押してください。\nマナーモードでも音声で教えてくれます。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if isCounting && countdown > 0 {
                    VStack(spacing: 8) {
                        Text("\(countdown)")
                            .font(.system(size: 80, weight: .black, design: .rounded))
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.spring, value: countdown)

                        Text("秒後に鳴ります…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 120)
                } else {
                    VStack(spacing: 12) {
                        Button {
                            Task { await startCountdown() }
                        } label: {
                            Label("今すぐテスト鳴動させる", systemImage: "bell.badge.fill")
                        }
                        .buttonStyle(.large(background: .blue))
                        .padding(.horizontal, 32)
                        .disabled(isCounting)
                    }
                    .frame(height: 120)
                }

                Text("画面が変わったら「とめる」を押してください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 160)
        }
        .fullScreenCover(isPresented: $showRinging) {
            RingingView(alarm: demoAlarm) {
                showRinging = false
                isCounting = false
                countdown = 0
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    /// カウントダウン開始 + 音声ファイルを事前生成する
    private func startCountdown() async {
        // 音声ファイルを事前生成（マナーモード貫通のため.cafをAVAudioPlayerで再生）
        let speechText = VoiceFileGenerator.speechText(for: demoAlarm)
        if let voiceURL = try? await voiceGenerator.generateAudio(
            text: speechText,
            character: .femaleConcierge,
            alarmID: demoAlarm.id
        ) {
            demoAlarm.voiceFileName = voiceURL.lastPathComponent
        }

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
}
