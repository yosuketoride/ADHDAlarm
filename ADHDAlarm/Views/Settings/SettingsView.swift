import SwiftUI
import EventKit

/// 設定画面
struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false
    /// PreNotificationPickerの選択状態をローカルで管理（@Observableのcomputed Bindingだと再描画されないため）
    @State private var preNotificationSet: Set<Int> = [15]

    var body: some View {
        NavigationStack {
            List {
                // プラン（最上部 — PRO状態が他の設定の前提になるため）
                Section {
                    if !viewModel.isPro {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("PROプランを見る", systemImage: "star.fill")
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Label("PRO会員", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("プラン")
                }

                // アラームの鳴り方（音声キャラクター・お知らせ方法・音の出力先をまとめて管理）
                Section {
                    VoiceCharacterPicker(
                        selection: Binding(
                            get: { viewModel.voiceCharacter },
                            set: { viewModel.voiceCharacter = $0 }
                        ),
                        isPro: viewModel.isPro,
                        onUpgradeTapped: { showPaywall = true }
                    )
                    .padding(.vertical, 8)

                    // 家族の生声が選択されている場合は録音管理リンクを表示
                    if viewModel.voiceCharacter == .customRecording && viewModel.isPro {
                        NavigationLink {
                            CustomVoiceRecorderView()
                        } label: {
                            Label("録音を管理する", systemImage: "waveform")
                        }
                    }

                    // お知らせ方法（アラーム音のみ or アラーム音+音声）
                    Picker("お知らせ方法", selection: Binding(
                        get: { viewModel.notificationType },
                        set: { viewModel.notificationType = $0 }
                    )) {
                        ForEach(NotificationType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    // 音の出力先
                    Picker("音の出力先", selection: Binding(
                        get: { viewModel.audioOutputMode },
                        set: { viewModel.audioOutputMode = $0 }
                    )) {
                        ForEach(AudioOutputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                } header: {
                    Text("アラームの鳴り方")
                }

                // お知らせのタイミング（グローバルデフォルト。PRO時は複数選択可）
                Section {
                    PreNotificationPicker(
                        selection: $preNotificationSet,
                        isPro: viewModel.isPro,
                        onUpgradeTapped: { showPaywall = true }
                    )
                    .padding(.vertical, 8)
                    .onChange(of: preNotificationSet) { _, newSet in
                        viewModel.preNotificationMinutes = newSet.min() ?? 15
                    }
                } header: {
                    Text("お知らせのタイミング")
                } footer: {
                    Text("予定を追加するときに個別に変更することもできます。")
                }

                // 入力（マイクの使い方）
                Section {
                    Picker("マイクの使い方", selection: Binding(
                        get: { viewModel.micInputMode },
                        set: { viewModel.micInputMode = $0 }
                    )) {
                        ForEach(MicInputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                } header: {
                    Text("入力")
                }

                // カレンダー選択（PRO限定）
                if viewModel.isPro {
                    Section {
                        calendarPicker
                    } header: {
                        Text("カレンダー")
                    }
                }

                // Hey Siri（PRO限定）
                Section {
                    if viewModel.isPro {
                        Label("「Hey Siri、こえメモにお願い」と話すだけで予定を登録できます。", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hey Siri でハンズフリー入力")
                                        .foregroundStyle(.primary)
                                    Text("アップグレードして有効にする")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Hey Siri（PRO）")
                }

                // 見守り: SOSエスカレーション（PRO限定）
                Section {
                    if viewModel.isPro {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.red)
                                .frame(width: 28)
                            TextField(
                                "家族の電話番号（例: 090-1234-5678）",
                                text: Binding(
                                    get: { viewModel.sosContactPhone },
                                    set: { viewModel.sosContactPhone = $0 }
                                )
                            )
                            .keyboardType(.phonePad)
                        }
                    } else {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill").foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("5分間応答なしで家族にお知らせ")
                                        .foregroundStyle(.primary)
                                    Text("アップグレードして有効にする")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("見守り（PRO）")
                } footer: {
                    if viewModel.isPro {
                        Text("アラームが5分間止められなかった場合、登録した番号にiMessageを自動送信します。")
                    }
                }

                // 自動化（全ユーザー無料）
                Section {
                    NavigationLink {
                        AutomationGuideView()
                    } label: {
                        Label("自動化の設定ガイド", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("自動化")
                } footer: {
                    Text("「ショートカット」アプリに連携すると、寝ている間に自動でお掃除してくれます。")
                }

                // 表示 — 見やすくする（PRO限定）
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.isAccessibilityModeEnabled },
                        set: {
                            if viewModel.isPro {
                                viewModel.isAccessibilityModeEnabled = $0
                            } else {
                                showPaywall = true
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("文字を大きく見やすくする")
                                if !viewModel.isPro {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .font(.body)
                            Text("タップしやすく、読みやすい画面に切り替えます（PRO）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!viewModel.isPro)
                } header: {
                    Text("表示")
                }

                // デバッグ: PROを強制有効化
                #if DEBUG
                Section {
                    Toggle(isOn: Binding(
                        get: { appState.subscriptionTier == .pro },
                        set: { appState.subscriptionTier = $0 ? .pro : .free }
                    )) {
                        Label("【DEBUG】PROを有効にする", systemImage: "wrench.fill")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("デバッグ")
                }
                #endif

                // お助けセンター
                Section {
                    NavigationLink {
                        RescueCenterView()
                    } label: {
                        Label("困ったときはここ！", systemImage: "hands.sparkles.fill")
                    }
                } header: {
                    Text("お助けセンター")
                } footer: {
                    Text("アラームが鳴らない・同期がうまくいかないときに開いてください。")
                }

                // プライバシー・情報
                Section {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.secondary)
                        Text("予定データはiPhoneの外には送信されません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("プライバシー")
                }
            }
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
        .task { await viewModel.loadCalendars() }
        .onAppear { preNotificationSet = Set([viewModel.preNotificationMinutes]) }
    }

    // MARK: - カレンダー選択（PRO）

    private var calendarPicker: some View {
        Picker("書き込み先カレンダー", selection: Binding(
            get: { viewModel.selectedCalendarID ?? "" },
            set: { viewModel.selectedCalendarID = $0.isEmpty ? nil : $0 }
        )) {
            Text("デフォルト").tag("")
            ForEach(viewModel.availableCalendars) { cal in
                Text(cal.title).tag(cal.id)
            }
        }
    }
}
