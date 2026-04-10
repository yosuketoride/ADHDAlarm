import SwiftUI

/// 家族ペアリング設定ビュー（設定画面の詳細設定内に表示）
struct FamilyLinkView: View {
    // レビュー指摘: State(initialValue:) を init で呼ぶ @State 初期化はアンチパターン。
    // 親が再描画されても初回の値が永続化されてしまう。プロパティ宣言で直接初期化する。
    @State private var viewModel = FamilyPairingViewModel()
    @Environment(AppState.self) private var appState
    /// この端末で予定を受け取るか、送るか
    @State private var selectedRole: Role = .parent
    @State private var showFamilyInput = false

    enum Role: String, CaseIterable {
        case parent = "予定を受け取る"
        case child  = "予定を送る"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    // ヘッダー説明
                    headerSection

                    // 既にリンク済みの場合（親として）
                    if let linkId = linkedLinkId {
                        linkedSection(linkId: linkId)
                    }

                    // 子として連携済みのリンクがある場合（送る側）
                    if !appState.familyChildLinkIds.isEmpty {
                        childLinksSection
                    }

                    // DEBUGビルド限定: 連携なしでも予定送信UIを確認できるボタン
                    #if DEBUG
                    if appState.familyChildLinkIds.isEmpty {
                        Button {
                            showFamilyInput = true
                        } label: {
                            Label("【DEBUG】予定送信UIを開く", systemImage: "hammer.fill")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                    #endif

                    // どちらでもない場合は連携UI
                    if linkedLinkId == nil && appState.familyChildLinkIds.isEmpty {
                        // ロール選択
                        rolePicker

                        // 状態に応じたUI
                        switch viewModel.state {
                        case .idle:
                            if selectedRole == .parent {
                                parentStartSection
                            } else {
                                childInputSection
                            }
                        case .generating, .joining:
                            ProgressView()
                                .padding()
                        case .waitingForFamily(let code, _, let seconds):
                            waitingSection(code: code, seconds: seconds)
                        case .linked:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                                .padding()
                        case .error(let message):
                            errorSection(message: message)
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle("家族と連携する")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFamilyInput) {
                let linkId = appState.familyChildLinkIds.first ?? "debug-link-id"
                FamilyInputView(
                    viewModel: FamilyInputViewModel(familyLinkId: linkId)
                )
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            // ペアリング完了時にAppStateに保存
            if case .linked(let linkId) = newState {
                if selectedRole == .parent {
                    appState.familyLinkId = linkId
                    Task {
                        let linkedIsPremium = await viewModel.fetchLinkedIsPremium(linkId: linkId)
                        if linkedIsPremium {
                            appState.subscriptionTier = .pro
                        }
                    }
                } else {
                    if !appState.familyChildLinkIds.contains(linkId) {
                        appState.familyChildLinkIds.append(linkId)
                    }
                }
            }
        }
    }

    // MARK: - サブビュー

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "person.2.fill")
                .font(.system(size: IconSize.xl))
                .foregroundStyle(.blue)
            Text("家族と予定を共有する")
                .font(.title3.weight(.bold))
            Text("離れて住む家族が、あなたのスマホにアラーム予定を直接送ることができます。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("この画面では、この端末で予定を受け取る設定と、別の端末へ予定を送る設定の両方ができます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var rolePicker: some View {
        Picker("連携方法", selection: $selectedRole) {
            ForEach(Role.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var parentStartSection: some View {
        VStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Label("コードを相手に伝える", systemImage: "number.square.fill")
                    .font(.headline)
                Text("この端末でコードを生成して、予定を送りたい相手に伝えてください。相手が入力すると連携できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            Button {
                viewModel.generateCode(isPremium: appState.subscriptionTier == .pro)
            } label: {
                Label("コードを生成する", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .blue))
        }
    }

    private var childInputSection: some View {
        VStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Label("受け取ったコードを入力", systemImage: "keyboard")
                    .font(.headline)
                Text("相手の端末に表示された6桁のコードを入力してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Color.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            TextField("6桁のコードを入力", text: $viewModel.inputCode)
                .keyboardType(.numberPad)
                .font(.system(.title2, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(Spacing.md)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            Button {
                viewModel.joinWithCode(isPremium: appState.subscriptionTier == .pro)
            } label: {
                Label("つながる", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .green))
            .disabled(viewModel.inputCode.count != 6)
        }
    }

    private func waitingSection(code: String, seconds: Int) -> some View {
        VStack(spacing: Spacing.lg) {
            Text("このコードを家族に伝えてください")
                .font(.callout)
                .foregroundStyle(.secondary)

            // 大きな数字コード表示
            Text(code)
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .tracking(8)
                .foregroundStyle(.blue)
                .padding(Spacing.md)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

            // 残り時間
            Label(
                "有効期限：あと\(seconds / 60)分\(seconds % 60)秒",
                systemImage: "clock"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button(role: .cancel) {
                viewModel.cancelWaiting()
            } label: {
                Text("キャンセル")
            }
            .buttonStyle(.bordered)
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private func linkedSection(linkId: String) -> some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("家族と連携済み")
                        .font(.headline)
                    Text("相手から予定が届くと、アラームが自動でセットされます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                viewModel.unlink(linkId: linkId)
                appState.familyLinkId = nil
            } label: {
                Label("連携を解除する", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    private func errorSection(message: String) -> some View {
        VStack(spacing: CornerRadius.md) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
                .multilineTextAlignment(.center)
            Button {
                viewModel.state = .idle
            } label: {
                Text("もう一度試す")
            }
            .buttonStyle(.bordered)
        }
        .padding(Spacing.md)
    }

    // MARK: - 子として連携済み（送る側）

    private var childLinksSection: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("予定を送れる状態です")
                        .font(.headline)
                    Text("この端末から相手の予定を登録できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showFamilyInput = true
            } label: {
                Label("予定を送る", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .blue))

            Button(role: .destructive) {
                if let linkId = appState.familyChildLinkIds.first {
                    viewModel.unlink(linkId: linkId)
                }
                appState.familyChildLinkIds = []
            } label: {
                Label("連携を解除する", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Helper

    private var linkedLinkId: String? {
        if let id = appState.familyLinkId, !id.isEmpty { return id }
        return nil
    }
}
