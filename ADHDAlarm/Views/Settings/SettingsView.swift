import SwiftUI
import AVFoundation
import AudioToolbox

/// 設定画面
///
/// 「開いた瞬間にやることがわかる」設計。
/// ・上部カード群：レスキュー / 声 / ふくろう名前 / PRO訴求
/// ・Listスタイルセクション：一般 / 家族と連携 / 料金プラン / その他
/// ・末尾：アカウント削除（Apple審査要件: 赤・明確に配置）
struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var showPaywall = false
    @State private var showOwlNameEditor = false
    @State private var owlNameDraft = ""
    @State private var isTesting = false
    @State private var showDeleteAccountConfirm = false
    private let tester = VolumeTestPlayer()

    #if DEBUG
    private struct VoiceDebugInfo: Identifiable {
        let identifier: String
        let name: String
        let language: String
        let qualityText: String
        var id: String { identifier }
    }
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // ① レスキューカード（最重要）
                    rescueCard

                    // ② 声カード（音声キャラクター + 聞き取りやすいこえ）
                    voiceCard

                    // ③ ふくろうの名前
                    owlNameCard

                    // ④ PRO訴求カード（無料ユーザーのみ）
                    if !viewModel.isPro { proCard }

                    // ── 一般 ──
                    generalSection

                    // ── 家族と連携 ──
                    familySection

                    // ── 料金プラン ──
                    planSection

                    // ── その他 ──
                    otherSection

                    // ── アカウント削除（Apple審査: 5.1.1 準拠）──
                    deleteAccountButton

                    // ── やり直し・バージョン ──
                    restartButton
                    footerText

                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .padding(.bottom, Spacing.xl)
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
            if newValue.count > 8 { owlNameDraft = String(newValue.prefix(8)) }
        }
        .confirmationDialog(
            "アカウントを削除しますか？",
            isPresented: $showDeleteAccountConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                Task {
                    do {
                        try await FamilyRemoteService.shared.deleteAccount()
                        appState.familyLinkId = nil
                        appState.familyChildLinkIds = []
                        appState.unreadFamilyEventCount = 0
                    } catch {
                        // 削除失敗時も画面は維持する
                    }
                }
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。家族との連携が解除されます。")
        }
        .task {
            await viewModel.loadCalendars()
        }
    }

    // MARK: - ① レスキューカード

    private var rescueCard: some View {
        SettingsCard {
            HStack(spacing: Spacing.sm) {
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

            Button {
                guard !isTesting else { return }
                isTesting = true
                tester.play { isTesting = false }
            } label: {
                Label(
                    isTesting ? "テスト中…" : "音量テストを鳴らす",
                    systemImage: isTesting ? "speaker.wave.3.fill" : "speaker.wave.3"
                )
            }
            .buttonStyle(.large(background: .orange))
            .disabled(isTesting)

            if !isTesting {
                HStack(alignment: .top, spacing: Spacing.sm) {
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

    // MARK: - ② 声カード（音声キャラクター + 聞き取りやすいこえ）

    private var voiceCard: some View {
        SettingsCard {
            VoiceCharacterPicker(
                selection: Binding(
                    get: { viewModel.voiceCharacter },
                    set: { viewModel.voiceCharacter = $0 }
                ),
                isPro: viewModel.isPro,
                onUpgradeTapped: { showPaywall = true }
            )

            // カスタム録音が選択されている場合は録音管理リンクを表示
            if viewModel.voiceCharacter == .customRecording && viewModel.isPro {
                Divider()
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

            Divider()

            // 聞き取りやすいこえ（詳細設定から昇格）
            Toggle(isOn: Binding(
                get: { appState.isClearVoiceEnabled },
                set: { appState.isClearVoiceEnabled = $0 }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("聞き取りやすいこえ")
                            .font(.body)
                        Text("声をゆっくり・低めに読み上げます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "ear.badge.checkmark")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: ComponentSize.settingRow)

            #if DEBUG
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("音声デバッグ")
                    .font(.subheadline.weight(.semibold))
                Text("使える日本語音声のidentifier/qualityを確認できます。")
                    .font(.caption).foregroundStyle(.secondary)
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

    // MARK: - ③ ふくろうの名前

    private var owlNameCard: some View {
        SettingsCard {
            Button {
                owlNameDraft = appState.owlName
                showOwlNameEditor = true
            } label: {
                HStack(spacing: Spacing.md) {
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
                .frame(minHeight: ComponentSize.settingRow)
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
    }

    // MARK: - ④ PRO訴求カード（無料ユーザーのみ）

    private var proCard: some View {
        SettingsCard {
            HStack(spacing: Spacing.md) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PROプランで、もっと安心に")
                        .font(.headline)
                    Text("家族への自動連絡・生声アラームなど")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button { showPaywall = true } label: {
                Text("PROプランを見る").frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .blue))
        }
    }

    // MARK: - 一般セクション

    private var generalSection: some View {
        SettingsSection(title: "一般") {
            // お知らせのタイミング
            NavigationLink {
                notificationTimingPage
            } label: {
                listRow(icon: "bell", title: "お知らせのタイミング")
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            // カレンダーを選ぶ（PRO）
            if viewModel.isPro {
                NavigationLink {
                    calendarSettingsPage
                } label: {
                    listRow(icon: "calendar", title: "カレンダーを選ぶ")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
            }

            // マイクの使い方
            NavigationLink {
                micSettingsPage
            } label: {
                listRow(icon: "mic", title: "マイクの使い方",
                        value: viewModel.micInputMode.displayName)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            // アラームの音の出力先
            NavigationLink {
                audioOutputPage
            } label: {
                listRow(icon: "speaker.wave.2", title: "アラームの音の出力先",
                        value: viewModel.audioOutputMode.displayName)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 家族と連携セクション

    private var familySection: some View {
        SettingsSection(title: "家族と連携") {
            // 家族への自動連絡（SOS）
            if viewModel.isPro {
                NavigationLink {
                    SOSSettingsView(settingsViewModel: viewModel)
                } label: {
                    listRow(icon: "bell.badge", title: "家族への自動連絡",
                            subtitle: "アラームへの応答がない場合に連絡")
                }
                .buttonStyle(.plain)
            } else {
                Button { showPaywall = true } label: {
                    listRow(icon: "bell.badge", title: "家族への自動連絡", proLocked: true)
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.leading, 52)

            // 家族から予定を受け取る
            if viewModel.isPro {
                NavigationLink {
                    PersonFamilyLinkView()
                } label: {
                    listRow(
                        icon: "person.2",
                        title: "家族から予定を受け取る",
                        subtitle: appState.familyLinkId != nil
                            ? "連携済み ✓"
                            : "家族が代わりに予定を登録できます"
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button { showPaywall = true } label: {
                    listRow(icon: "person.2", title: "家族から予定を受け取る", proLocked: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 料金プランセクション

    private var planSection: some View {
        SettingsSection(title: "料金プラン") {
            Button { showPaywall = true } label: {
                listRow(
                    icon: "star",
                    title: "ふくろう PRO",
                    value: viewModel.isPro ? "PRO" : "無料"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - その他セクション

    private var otherSection: some View {
        SettingsSection(title: "その他") {
            // よくある質問（Notionページ、URL確定後に設定）
            if let url = Constants.LegalURL.faqURL {
                Link(destination: url) {
                    listRow(icon: "questionmark.circle", title: "よくある質問")
                }
                .foregroundStyle(.primary)
            } else {
                listRow(icon: "questionmark.circle", title: "よくある質問")
                    .foregroundStyle(.tertiary)
            }

            Divider().padding(.leading, 52)

            // お問い合わせ（mailto:）
            if let url = Constants.LegalURL.supportMailURL {
                Link(destination: url) {
                    listRow(icon: "envelope", title: "お問い合わせ")
                }
                .foregroundStyle(.primary)
            }

            Divider().padding(.leading, 52)

            // 利用規約
            if let url = URL(string: Constants.LegalURL.terms) {
                Link(destination: url) {
                    listRow(icon: "doc.text", title: "利用規約")
                }
                .foregroundStyle(.primary)
            }

            Divider().padding(.leading, 52)

            // プライバシーポリシー
            if let url = URL(string: Constants.LegalURL.privacy) {
                Link(destination: url) {
                    listRow(icon: "lock.shield", title: "プライバシーポリシー")
                }
                .foregroundStyle(.primary)
            }

            Divider().padding(.leading, 52)

            // レビューで応援する
            if let url = Constants.LegalURL.appStoreReviewURL {
                Link(destination: url) {
                    listRow(icon: "heart", title: "レビューで応援する",
                            subtitle: "ストアでレビューを書いて応援してください")
                }
                .foregroundStyle(.primary)
            } else {
                listRow(icon: "heart", title: "レビューで応援する",
                        subtitle: "ストアでレビューを書いて応援してください")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - アカウント削除ボタン（Apple審査: 5.1.1 準拠 — 明確に配置）

    private var deleteAccountButton: some View {
        Button(role: .destructive) {
            showDeleteAccountConfirm = true
        } label: {
            Text("アカウントを削除する")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.large(background: Color.red.opacity(0.08), foreground: .red))
    }

    // MARK: - 最初からやり直しボタン

    private var restartButton: some View {
        Button {
            appState.isOnboardingComplete = false
            appState.appMode = nil
        } label: {
            Label("最初の設定をやり直す", systemImage: "arrow.counterclockwise")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - フッター（プライバシー + バージョン）

    private var footerText: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield").foregroundStyle(.secondary)
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
    }

    // MARK: - 行ヘルパー（モノクロアイコン + iOS Settingsスタイル）

    private func listRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        proLocked: Bool = false
    ) -> some View {
        HStack(spacing: Spacing.md) {
            // モノクロアイコン（グレー丸角背景）
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(.systemGray))
                .frame(width: 28, height: 28)
                .background(Color(.systemGray5),
                            in: RoundedRectangle(cornerRadius: CornerRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(proLocked ? .secondary : .primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if proLocked {
                Text("PRO")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.owlAmber)
                    .clipShape(Capsule())
            } else if let value {
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(minHeight: ComponentSize.settingRow)
        .padding(.horizontal, Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - 詳細ページ定義（NavigationLink先）

    private var notificationTimingPage: some View {
        List {
            Section {
                PreNotificationPicker(
                    selection: Binding(
                        get: { viewModel.preNotificationMinutesList },
                        set: { viewModel.preNotificationMinutesList = $0 }
                    ),
                    isPro: viewModel.isPro,
                    onUpgradeTapped: { showPaywall = true }
                )
                .padding(.vertical, Spacing.sm)
            } footer: {
                Text("予定を追加するときに個別に変更することもできます。")
            }
        }
        .navigationTitle("お知らせのタイミング")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calendarSettingsPage: some View {
        List {
            Section {
                Picker("カレンダーを選ぶ", selection: Binding(
                    get: { viewModel.selectedCalendarID ?? "" },
                    set: { viewModel.selectedCalendarID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("デフォルト").tag("")
                    ForEach(viewModel.availableCalendars) { cal in
                        Text(cal.title).tag(cal.id)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("予定を書き込むカレンダーを選んでください")
            }
        }
        .navigationTitle("カレンダーを選ぶ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var micSettingsPage: some View {
        List {
            Section {
                Picker("マイクの使い方", selection: Binding(
                    get: { viewModel.micInputMode },
                    set: { viewModel.micInputMode = $0 }
                )) {
                    ForEach(MicInputMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("マイクの使い方")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var audioOutputPage: some View {
        List {
            Section {
                Picker("音の出力先", selection: Binding(
                    get: { viewModel.audioOutputMode },
                    set: { viewModel.audioOutputMode = $0 }
                )) {
                    ForEach(AudioOutputMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("アラームの音の出力先")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - デバッグセクション

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

    private var availableJapaneseVoices: [VoiceDebugInfo] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") }
            .map { VoiceDebugInfo(identifier: $0.identifier, name: $0.name,
                                  language: $0.language, qualityText: qualityText(for: $0.quality)) }
            .sorted { $0.qualityText == $1.qualityText
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : $0.qualityText < $1.qualityText }
    }

    private func qualityText(for quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium:  return "premium"
        case .enhanced: return "enhanced"
        default:        return "default"
        }
    }
    #endif
}

// MARK: - SettingsSection（グループ化リスト行のコンテナ）

private struct SettingsSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.sm)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
    }
}

// MARK: - SettingsCard（上部カード群）

/// 設定画面用の白いカード。
/// レビュー指摘: @ScaledMetric を余白に使うとaccessibility3以上で余白が異常膨張し
/// コンテンツが画面外に押し出されるレイアウト崩壊が起きる。固定値（Spacing.lg）を使用。
private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            content()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - VolumeTestPlayer（音量テスト用）

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

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                            didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false,
                                                       options: .notifyOthersOnDeactivation)
        speechSynthesizer = nil
        let cb = onFinish
        onFinish = nil
        DispatchQueue.main.async { cb?() }
    }
}
