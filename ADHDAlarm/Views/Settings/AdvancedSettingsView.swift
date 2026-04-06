import SwiftUI

/// 詳細設定画面（二軍）
/// 頻繁に触らないマニアックな設定をここに集約する。
/// 設定慣れしているユーザーが来る前提なので、標準のList形式で問題ない。
struct AdvancedSettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false
    @State private var showDeleteAccountConfirm = false
    @State private var pairingViewModel: SOSPairingViewModel?

    var body: some View {
        List {
            // アラームの鳴り方（音の出力先）
            Section {
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
                    Label("「Hey Siri、ふくろうにお願い」と話すだけで予定を登録できます。", systemImage: "checkmark.circle.fill")
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

            // 家族リモートスケジュール（PRO限定）
            Section {
                if viewModel.isPro {
                    NavigationLink {
                        PersonFamilyLinkView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("家族と連携する")
                                    .foregroundStyle(.primary)
                                Text(appState.familyLinkId != nil ? "連携済み" : "家族が代わりに予定を登録できます")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if appState.familyLinkId != nil {
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                } else {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("家族が代わりに予定を登録")
                                    .foregroundStyle(.primary)
                                Text("アップグレードして有効にする")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("家族リモートスケジュール（PRO）")
            } footer: {
                Text("家族のスマホから親の予定を登録すると、自動でアラームがセットされます。")
            }

            // 自動化（全ユーザー無料）
            Section {
                NavigationLink {
                    AutomationGuideView()
                } label: {
                    Label("自動化の設定ガイド", systemImage: "wand.and.stars")
                }
                .contentShape(Rectangle())
            } header: {
                Text("自動化")
            } footer: {
                Text("「ショートカット」アプリに連携すると、寝ている間に自動でお掃除してくれます。")
            }

            // ⚠️ 危険な操作（最下部に配置）
            Section {
                Button(role: .destructive) {
                    showDeleteAccountConfirm = true
                } label: {
                    Label("アカウントを削除する", systemImage: "person.crop.circle.badge.minus")
                }
            } header: {
                Text("データの削除")
            } footer: {
                Text("家族とのペアリング情報・送受信履歴がすべて削除されます。アラームのローカルデータはiPhoneに残ります。")
            }
        }
        .navigationTitle("詳細設定")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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
            if pairingViewModel == nil {
                // レビュー指摘: SwiftUIの.taskはMainActorで実行されるため
                // await MainActor.run { } は不要かつ無駄な再描画を引き起こす。
                pairingViewModel = SOSPairingViewModel(appState: appState)
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
