import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit

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
    @State private var isDeletingAccount = false
    @State private var showWidgetGuide = false
    private let tester = VolumeTestPlayer()

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
            .background(.background)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showWidgetGuide) {
            NavigationStack {
                WidgetGuideView {
                    showWidgetGuide = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { showWidgetGuide = false }
                    }
                }
            }
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
                    isDeletingAccount = true
                    do {
                        try await FamilyRemoteService.shared.deleteAccount()
                        appState.familyLinkId = nil
                        appState.familyChildLinkIds = []
                        appState.unreadFamilyEventCount = 0
                        appState.isOnboardingComplete = false
                        appState.appMode = nil
                        appState.dismissAllSheets = true
                    } catch {
                        ToastWindowManager.shared.show(ToastMessage(
                            text: "うまく削除できませんでした。少し待ってもう一度試してみてください",
                            style: .error
                        ))
                    }
                    isDeletingAccount = false
                }
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。家族との連携が解除されます。")
        }
        .overlay {
            if isDeletingAccount {
                deletingOverlay
            }
        }
        .interactiveDismissDisabled(isDeletingAccount)
        .disabled(isDeletingAccount)
        .task {
            await viewModel.loadCalendars()
        }
    }

    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                Text("削除中...")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(Spacing.xl)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
    }

    // MARK: - ① レスキューカード

    private var rescueCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SettingsSection {
                // 音量テスト
                Button {
                    guard !isTesting else { return }
                    isTesting = true
                    tester.play { isTesting = false }
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: isTesting ? "speaker.wave.3.fill" : "speaker.wave.3")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isTesting ? Color.orange : Color(.systemGray))
                            .frame(width: 28, height: 28)
                            .background(Color(.systemGray5),
                                        in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                        Text(isTesting ? "テスト中…" : "音量テストを鳴らす")
                            .font(.body)
                            .foregroundStyle(isTesting ? .secondary : .primary)
                        Spacer()
                        if isTesting {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                    .frame(minHeight: ComponentSize.settingRow)
                    .padding(.horizontal, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isTesting)

                Divider().padding(.leading, 52)

                // お助けセンター
                NavigationLink {
                    RescueCenterView()
                } label: {
                    listRow(icon: "questionmark.circle", title: "お助けセンターを開く")
                }
                .buttonStyle(.plain)
            }

            Text("音が小さい場合は、iPhoneの横の音量ボタン（＋）を押してください。マナーモードでも鳴ります。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.sm)
        }
    }

    // MARK: - ② 声の設定（音声キャラクター + 聞き取りやすいこえ）

    private var voiceCard: some View {
        SettingsSection(title: "声の設定") {
            // 音声キャラクター（3行リスト）
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
                Divider().padding(.leading, 52)
                NavigationLink {
                    CustomVoiceRecorderView()
                } label: {
                    listRow(icon: "waveform", title: "録音を管理する")
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.leading, 52)

            // 聞き取りやすいこえ（コンパクトToggle）
            Toggle(isOn: Binding(
                get: { appState.isClearVoiceEnabled },
                set: { appState.isClearVoiceEnabled = $0 }
            )) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "ear.badge.checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray5),
                                    in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                    Text("聞き取りやすいこえ")
                        .font(.body)
                }
            }
            .frame(minHeight: ComponentSize.settingRow)
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - ③ ふくろうの名前

    private var owlNameCard: some View {
        SettingsSection {
            Button {
                owlNameDraft = appState.owlName
                showOwlNameEditor = true
            } label: {
                listRow(
                    icon: "bird",
                    title: "ふくろうの名前",
                    value: appState.owlName
                )
            }
            .buttonStyle(.plain)
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

            // カレンダーを選ぶ（PRO・非PROどちらも表示、非PROはPaywall）
            if viewModel.isPro {
                NavigationLink {
                    calendarSettingsPage
                } label: {
                    listRow(icon: "calendar", title: "カレンダーを選ぶ")
                }
                .buttonStyle(.plain)
            } else {
                Button { showPaywall = true } label: {
                    listRow(icon: "calendar", title: "カレンダーを選ぶ", proLocked: true)
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.leading, 52)

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
                    title: "忘れん坊アラーム PRO",
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

            // お問い合わせ（mailto: + デバイス情報付き）
            if let url = supportMailURL {
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

            Button {
                showWidgetGuide = true
            } label: {
                listRow(icon: "rectangle.stack.badge.plus", title: "ウィジェットの置き方")
            }
            .buttonStyle(.plain)

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
            Text("忘れん坊アラーム v\(version) (\(build))")
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
                    .foregroundStyle(.black)
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
                    Text("自動で選ぶ").tag("")
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

    // MARK: - お問い合わせURL（デバイス情報を本文に付与）

    private var supportMailURL: URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let osVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        let inquiryID = FamilyRemoteService.shared.currentDeviceId ?? "未ログイン"

        let subject = "【忘れん坊アラーム】お問い合わせ"
        let body = """


---
（以下は自動入力です。変更しないでください）
お問い合わせID: \(inquiryID)
App: \(version)
OS: iOS \(osVersion)
Device: \(model)
"""
        guard
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "mailto:yosuketoride@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    // MARK: - デバッグセクション

    #if DEBUG
    private var debugSection: some View {
        SettingsSection(isCard: true) {
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

// MARK: - SettingsSection（グループ化リスト行のコンテナ）

private struct SettingsSection<Content: View>: View {
    let title: String?
    /// true のときはリスト行ではなくカード型レイアウト（内側に Spacing.lg のパディング）
    let isCard: Bool
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, isCard: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isCard = isCard
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
            Group {
                if isCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        content()
                    }
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        content()
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
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
