import SwiftUI

/// 家族モード開始時に6桁コードを入力してペアリングする画面
struct FamilyPairingView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FamilyPairingViewModel()
    @FocusState private var isFocused: Bool
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                codeInputCard
                statusSection
                switchModeButton
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xl)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            isFocused = true
        }
        .onChange(of: viewModel.inputCode) { _, newValue in
            let filtered = newValue.filter(\.isNumber)
            let trimmed = String(filtered.prefix(6))
            if trimmed != newValue {
                viewModel.inputCode = trimmed
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            if case .linked(let linkId) = newState,
               !appState.familyChildLinkIds.contains(linkId) {
                appState.familyChildLinkIds.append(linkId)
                // ペアリング完了 → PRO未加入の場合は家族向けペイウォールを表示
                if appState.subscriptionTier != .pro {
                    showPaywall = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            FamilyPaywallView()
        }
    }

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.owlAmber.opacity(0.14))
                    .frame(width: 88, height: 88)
                Text("🦉")
                    .font(.system(size: 40))
            }

            VStack(spacing: Spacing.sm) {
                Text("ペアリングしよう")
                    .font(.title.weight(.bold))
                Text("「自分で使う」側の6桁コードを入力してね")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var codeInputCard: some View {
        VStack(spacing: Spacing.lg) {
            Button {
                isFocused = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<6, id: \.self) { index in
                        codeCell(characterAt(index))
                    }
                }
            }
            .buttonStyle(.plain)

            TextField("", text: $viewModel.inputCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)

            Button {
                viewModel.joinWithCode(isPremium: appState.subscriptionTier == .pro)
            } label: {
                Label("コードを入力してペアリング", systemImage: "link")
            }
            .buttonStyle(.large(background: .blue))
            .disabled(viewModel.inputCode.count != 6 || isBusy)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    @ViewBuilder
    private var statusSection: some View {
        switch viewModel.state {
        case .idle:
            ConciergeText(message: "コードを入力すると、家族から予定を送れるようになります。")

        case .joining:
            ProgressView("つないでいます…")

        case .linked:
            VStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: IconSize.xl))
                    .foregroundStyle(Color.statusSuccess)
                Text("ペアリングできました")
                    .font(.headline)
                Text("このままホーム画面に進めます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        case .error(let message):
            VStack(spacing: Spacing.sm) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.statusDanger)
                    .multilineTextAlignment(.center)
                Button("もう一度試す") {
                    viewModel.state = .idle
                    isFocused = true
                }
                .buttonStyle(.bordered)
            }

        case .generating, .waitingForFamily:
            EmptyView()
        }
    }

    private var switchModeButton: some View {
        Button {
            appState.appMode = .person
        } label: {
            Text("やっぱり自分で使う")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 60)
    }

    private func codeCell(_ character: String) -> some View {
        Text(character)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.owlAmber.opacity(character.isEmpty ? 0.35 : 1), lineWidth: BorderWidth.thick)
            }
            .accessibilityLabel(character.isEmpty ? "未入力" : character)
    }

    private func characterAt(_ index: Int) -> String {
        guard index < viewModel.inputCode.count else { return "" }
        let stringIndex = viewModel.inputCode.index(viewModel.inputCode.startIndex, offsetBy: index)
        return String(viewModel.inputCode[stringIndex])
    }

    private var isBusy: Bool {
        if case .joining = viewModel.state {
            return true
        }
        return false
    }
}
