import SwiftUI

/// 詳細設定画面（二軍）
/// 頻繁に触らないマニアックな設定をここに集約する。
/// 設定慣れしているユーザーが来る前提なので、標準のList形式で問題ない。
struct AdvancedSettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false
    @State private var pairingViewModel: SOSPairingViewModel?

    var body: some View {
        List {
            // アラームの鳴り方（お知らせ方法・音の出力先）
            Section {
                Picker("お知らせ方法", selection: Binding(
                    get: { viewModel.notificationType },
                    set: { viewModel.notificationType = $0 }
                )) {
                    ForEach(NotificationType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

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

            // お知らせのタイミング
            Section {
                PreNotificationPicker(
                    selection: Binding(
                        get: { viewModel.preNotificationMinutesList },
                        set: { viewModel.preNotificationMinutesList = $0 }
                    ),
                    isPro: viewModel.isPro,
                    onUpgradeTapped: { showPaywall = true }
                )
                .padding(.vertical, 8)
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
                            Image(systemName: "star.fill").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hey Siriでハンズフリー入力")
                                    .foregroundStyle(.primary)
                                Text("アップグレードして有効にする")
                                    .font(.caption).foregroundStyle(.secondary)
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
                    if let pairingVM = pairingViewModel {
                        SOSPairingView(viewModel: pairingVM)
                            .padding(.vertical, 4)
                        
                        Divider()
                    }
                    
                    Picker("お知らせするまでの時間", selection: Binding(
                        get: { viewModel.sosEscalationMinutes },
                        set: { viewModel.sosEscalationMinutes = $0 }
                    )) {
                        #if DEBUG
                        Text("10秒（テスト用）").tag(0)
                        #endif
                        ForEach([1, 3, 5, 10, 15, 20], id: \.self) { min in
                            Text("\(min)分").tag(min)
                        }
                    }
                } else {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("応答なしで家族にお知らせ")
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
                    Text("アラームが\(viewModel.sosEscalationMinutes == 0 ? "10秒（テスト）" : "\(viewModel.sosEscalationMinutes)分")間止められなかった場合、連携済みのLINEに自動でお知らせが届きます。")
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
        }
        .navigationTitle("詳細設定")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                viewModel: PaywallViewModel(
                    storeKit: StoreKitService(),
                    appState: appState
                )
            )
        }
        .task {
            await viewModel.loadCalendars()
            if pairingViewModel == nil {
                pairingViewModel = await MainActor.run { SOSPairingViewModel(appState: appState) }
            }
        }
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
