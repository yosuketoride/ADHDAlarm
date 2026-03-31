import SwiftUI
import AVFoundation
import AudioToolbox

/// 設定画面（一軍のみ）
///
/// 「開いた瞬間にやることがわかる」設計。
/// 頻繁に触わない詳細設定は「詳細設定」カードの奥に隠す（段階的開示）。
struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var showPaywall = false
    @State private var isTesting = false
    private let tester = VolumeTestPlayer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ① レスキューカード（最重要: 「鳴らないかも」不安を解消）
                    rescueCard

                    // ② 音声キャラクターカード（唯一の「楽しい」設定）
                    voiceCharacterCard

                    // ③ PROプランカード（無料ユーザーのみ）
                    if !viewModel.isPro {
                        proCard
                    }

                    // ④ 詳細設定カード（控えめに）
                    advancedCard

                    // フッター（プライバシー + バージョン）
                    footerSection

                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .padding(.bottom, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                viewModel: PaywallViewModel(
                    storeKit: StoreKitService(),
                    appState: appState
                )
            )
        }
    }

    // MARK: - ① レスキューカード

    private var rescueCard: some View {
        SettingsCard {
            // ヘッダー
            HStack(spacing: 10) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("アラームが鳴るか不安ですか？")
                        .font(.headline)
                    Text("ここで今すぐ確認できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 音量テストボタン（最も目立つ特等席）
            Button {
                guard !isTesting else { return }
                isTesting = true
                tester.play {
                    isTesting = false
                }
            } label: {
                Label(
                    isTesting ? "テスト中…" : "音量テストを鳴らす",
                    systemImage: isTesting ? "speaker.wave.3.fill" : "speaker.wave.3"
                )
            }
            .buttonStyle(.large(background: .orange))
            .disabled(isTesting)

            // 音が小さかった場合の案内
            if !isTesting {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.top, 1)
                    Text("音が小さかったら、iPhoneの横にある音量ボタン（＋）を押して音量を上げてください。アラームはマナーモードがオンでも鳴ります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // お助けセンターリンク
            NavigationLink {
                RescueCenterView()
            } label: {
                HStack {
                    Label("お助けセンターを開く", systemImage: "chevron.right.circle")
                        .foregroundStyle(.orange)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - ② 音声キャラクターカード

    private var voiceCharacterCard: some View {
        SettingsCard {
            VoiceCharacterPicker(
                selection: Binding(
                    get: { viewModel.voiceCharacter },
                    set: { viewModel.voiceCharacter = $0 }
                ),
                isPro: viewModel.isPro,
                onUpgradeTapped: { showPaywall = true }
            )

            // 家族の生声が選択されている場合は録音管理リンクを表示
            if viewModel.voiceCharacter == .customRecording && viewModel.isPro {
                NavigationLink {
                    CustomVoiceRecorderView()
                } label: {
                    HStack {
                        Label("録音を管理する", systemImage: "waveform")
                            .foregroundStyle(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - ③ PROプランカード（無料ユーザーのみ）

    private var proCard: some View {
        SettingsCard {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PROプランで、もっと安心に")
                        .font(.headline)
                    Text("家族へのSOS自動通知・生声アラームなど")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                showPaywall = true
            } label: {
                Text("PROプランを見る")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .blue))
        }
    }

    // MARK: - ④ 詳細設定カード

    private var advancedCard: some View {
        NavigationLink {
            AdvancedSettingsView(viewModel: viewModel)
        } label: {
            SettingsCard {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("詳細設定")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("通知タイミング・カレンダー・Siriなど")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - フッター

    private var footerSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
                Text("予定データはiPhoneの外には送信されません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
            Text("ふくろう v\(version) (\(build))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 4)
    }

    // MARK: - デバッグ

    #if DEBUG
    private var debugSection: some View {
        SettingsCard {
            Toggle(isOn: Binding(
                get: { appState.subscriptionTier == .pro },
                set: { appState.subscriptionTier = $0 ? .pro : .free }
            )) {
                Label("【DEBUG】PROを有効にする", systemImage: "wrench.fill")
                    .foregroundStyle(.orange)
            }

            Button {
                appState.isOnboardingComplete = false
                appState.appMode = nil
            } label: {
                Label("【DEBUG】オンボーディングをやり直す", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.orange)
            }
        }
    }
    #endif
}

// MARK: - カードコンポーネント

/// 設定画面用の白いカード。余白が文字サイズに連動してスケールする。
private struct SettingsCard<Content: View>: View {
    // レビュー指摘: @ScaledMetric を余白に使うとaccessibility3以上で余白が異常膨張し
    // コンテンツが画面外に押し出されるレイアウト崩壊が起きる。固定値に変更。
    private let cardPadding: CGFloat = 20
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: cardPadding * 0.75) {
            content()
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - 爆音テストプレーヤー（設定トップ用）

/// 音量テスト: ビープ + TTS音声をAVSpeechSynthesizerで再生する
private final class VolumeTestPlayer: NSObject, AVSpeechSynthesizerDelegate {
    private var speechSynthesizer: AVSpeechSynthesizer?
    private var onFinish: (() -> Void)?

    func play(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        // ビープ先行（着信音量）
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                AudioServicesPlayAlertSound(1005)
            }
        }
        // 1秒後にTTSで音声テスト
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("【音量テスト】セッション確保失敗: \(error.localizedDescription)")
            }
            let synthesizer = AVSpeechSynthesizer()
            synthesizer.delegate = self
            let utterance = AVSpeechUtterance(string: "テストです！この音量でアラームが鳴ります。聞こえていますか？")
            utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
            utterance.rate = 0.48
            utterance.pitchMultiplier = 1.1
            synthesizer.speak(utterance)
            self.speechSynthesizer = synthesizer
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        speechSynthesizer = nil
        let cb = onFinish
        onFinish = nil
        DispatchQueue.main.async { cb?() }
    }
}
