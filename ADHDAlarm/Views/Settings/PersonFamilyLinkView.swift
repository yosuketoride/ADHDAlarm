import SwiftUI

/// 本人モード専用の家族ペアリング設定ビュー
/// 家族が代わりに予定を登録できるように、受け取り用コードだけを発行する
struct PersonFamilyLinkView: View {
    // レビュー指摘: @State は宣言時に直接初期化し、再描画時の値固定を避ける。
    @State private var viewModel = FamilyPairingViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if let linkId = linkedLinkId {
                        linkedSection(linkId: linkId)
                    } else {
                        switch viewModel.state {
                        case .idle:
                            parentStartSection
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
            // ペアリング完了時は受け取り用 linkId のみ保存する
            if case .linked(let linkId) = newState {
                appState.familyLinkId = linkId
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
            Text("家族が代わりに予定を登録できるよう、連携コードを発行します。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var parentStartSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("コードを家族に伝える", systemImage: "number.square.fill")
                    .font(.headline)
                Text("この端末でコードを生成して、予定を登録してくれる家族に伝えてください。コードを入力すると連携できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                viewModel.generateCode(isPremium: appState.subscriptionTier == .pro)
            } label: {
                Label("コードを生成する", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 60)
            }
            .buttonStyle(.large(background: .blue))
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
                    .frame(minHeight: 60)
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
                    .frame(minHeight: 60)
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
                    .frame(minHeight: 60)
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
