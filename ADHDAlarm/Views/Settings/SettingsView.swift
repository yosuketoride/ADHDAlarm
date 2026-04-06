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
    @State private var showOwlNameEditor = false
    @State private var owlNameDraft = ""
    @State private var isTesting = false
    private let tester = VolumeTestPlayer()

    private struct VoiceDebugInfo: Identifiable {
        let identifier: String
        let name: String
        let language: String
        let qualityText: String

        var id: String { identifier }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ① レスキューカード（最重要: 「鳴らないかも」不安を解消）
                    rescueCard

                    // ② 音声キャラクターカード（唯一の「楽しい」設定）
                    voiceCharacterCard

                    // ③ ふくろうの名前
                    owlNameCard

                    // ④ PROプランカード（無料ユーザーのみ）
                    if !viewModel.isPro {
                        proCard
                    }

                    // ⑤ 詳細設定カード（控えめに）
                    advancedCard

                    // フッター（プライバシー + バージョン）
                    footerSection

                    // モードやり直しボタン（常に表示）
                    restartOnboardingSection

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
            PaywallView()
        }
        .alert("ふくろうの名前を変える", isPresented: $showOwlNameEditor) {
            TextField("ふくろう", text: $owlNameDraft)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                let trimmed = owlNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                appState.owlName = trimmed.isEmpty ? "ふくろう" : trimmed
            }
        } message: {
            Text("8文字までで入力できます。")
        }
        .onChange(of: owlNameDraft) { _, newValue in
            if newValue.count > 8 {
                owlNameDraft = String(newValue.prefix(8))
            }
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
            .contentShape(Rectangle())
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
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }

            #if DEBUG
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("音声デバッグ")
                    .font(.subheadline.weight(.semibold))
                Text("使える日本語音声の identifier と quality を確認できます。Siri の「声1 / 声2」の実体確認用です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(availableJapaneseVoices) { voice in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(voice.name) • \(voice.qualityText)")
                            .font(.caption.weight(.semibold))
                        Text(voice.identifier)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Text(voice.language)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            #endif
        }
    }

    #if DEBUG
    private var availableJapaneseVoices: [VoiceDebugInfo] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") }
            .map {
                VoiceDebugInfo(
                    identifier: $0.identifier,
                    name: $0.name,
                    language: $0.language,
                    qualityText: qualityText(for: $0.quality)
                )
            }
            .sorted {
                if $0.qualityText == $1.qualityText {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.qualityText < $1.qualityText
            }
    }

    private func qualityText(for quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium:
            return "premium"
        case .enhanced:
            return "enhanced"
        default:
            return "default"
        }
    }
    #endif

    // MARK: - ③ ふくろうの名前

    private var owlNameCard: some View {
        SettingsCard {
            Button {
                owlNameDraft = appState.owlName
                showOwlNameEditor = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bird.fill")
                        .font(.title2)
                        .foregroundStyle(Color.owlAmber)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ふくろうの名前")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(appState.owlName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 60)
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
    }

    // MARK: - ④ PROプランカード（無料ユーザーのみ）

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

    // MARK: - ⑤ 詳細設定カード

    private var advancedCard: some View {
        SettingsCard {
            NavigationLink {
                AdvancedSettingsView(viewModel: viewModel)
            } label: {
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
                .frame(minHeight: ComponentSize.settingRow)
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)

            Divider()

            // クリアボイスモード
            Toggle(isOn: Binding(
                get: { appState.isClearVoiceEnabled },
                set: { appState.isClearVoiceEnabled = $0 }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("聞き取りやすいこえ")
                            .font(.body)
                        Text("アラームの声をゆっくり・低めに読み上げます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "ear.badge.checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .frame(minHeight: ComponentSize.settingRow)
            .contentShape(Rectangle())
        }
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

    // MARK: - モードやり直し

    private var restartOnboardingSection: some View {
        SettingsCard {
            Button {
                appState.isOnboardingComplete = false
                appState.appMode = nil
            } label: {
                Label("最初の設定をやり直す", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 60)
        }
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
