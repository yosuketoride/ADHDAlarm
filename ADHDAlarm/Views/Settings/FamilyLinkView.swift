import SwiftUI

/// 家族ペアリング設定ビュー（設定画面の詳細設定内に表示）
struct FamilyLinkView: View {
    @State private var viewModel: FamilyPairingViewModel
    @Environment(AppState.self) private var appState
    /// 親として連携するか、子として連携するか
    @State private var selectedRole: Role = .parent

    enum Role: String, CaseIterable {
        case parent = "受け取る（親）"
        case child  = "送る（子）"
    }

    init(viewModel: FamilyPairingViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? FamilyPairingViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ヘッダー説明
                    headerSection

                    // 既にリンク済みの場合
                    if let linkId = linkedLinkId {
                        linkedSection(linkId: linkId)
                    } else {
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
                .padding()
            }
            .navigationTitle("家族と連携する")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: viewModel.state) { _, newState in
            // ペアリング完了時にAppStateに保存
            if case .linked(let linkId) = newState {
                if selectedRole == .parent {
                    appState.familyLinkId = linkId
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
        VStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("家族と予定を共有する")
                .font(.title3.weight(.bold))
            Text("離れて住む家族が、あなたのスマホにアラーム予定を直接送ることができます。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var rolePicker: some View {
        Picker("役割", selection: $selectedRole) {
            ForEach(Role.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var parentStartSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("コードを子に教える", systemImage: "number.square.fill")
                    .font(.headline)
                Text("「受け取る側（親）」でコードを生成して、子に伝えてください。子が入力するとつながります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                viewModel.generateCode()
            } label: {
                Label("コードを生成する", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .blue))
        }
    }

    private var childInputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("親から教えてもらったコードを入力", systemImage: "keyboard")
                    .font(.headline)
                Text("親のスマホに表示された6桁のコードを入力してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            TextField("6桁のコードを入力", text: $viewModel.inputCode)
                .keyboardType(.numberPad)
                .font(.system(.title2, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                viewModel.joinWithCode()
            } label: {
                Label("つながる", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .green))
            .disabled(viewModel.inputCode.count != 6)
        }
    }

    private func waitingSection(code: String, seconds: Int) -> some View {
        VStack(spacing: 20) {
            Text("このコードを家族に伝えてください")
                .font(.callout)
                .foregroundStyle(.secondary)

            // 大きな数字コード表示
            Text(code)
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .tracking(8)
                .foregroundStyle(.blue)
                .padding()
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

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
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func linkedSection(linkId: String) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("家族と連携済み")
                        .font(.headline)
                    Text("家族から予定が届くと、アラームが自動でセットされます。")
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
        VStack(spacing: 12) {
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
        .padding()
    }

    // MARK: - Helper

    private var linkedLinkId: String? {
        if let id = appState.familyLinkId, !id.isEmpty { return id }
        return nil
    }
}
