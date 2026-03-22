import SwiftUI
import StoreKit

/// PRO機能比較 + 購入ボタン
struct PaywallView: View {
    @State var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    featureComparisonSection
                    purchaseSection
                    footerSection
                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("PROプラン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .overlay {
                if let msg = viewModel.successMessage {
                    successOverlay(msg)
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    // MARK: - ヘッダー

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("こえメモ PRO")
                .font(.title.weight(.bold))

            Text("マナーモード貫通アラームの\nすべての機能が使えます。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 機能比較

    private var featureComparisonSection: some View {
        VStack(spacing: 0) {
            featureHeader
            featureRow("カレンダー選択",      free: "デフォルトのみ",    pro: "自由に選択")
            featureRow("事前通知",            free: "1回（15分前）",    pro: "最大3回まで")
            featureRow("音声キャラクター",    free: "コンシェルジュのみ", pro: "執事キャラも選択可")
            featureRow("テーマ",              free: "B&W",             pro: "全テーマ")
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var featureHeader: some View {
        HStack {
            Text("機能").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            Text("無料").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 80)
            Text("PRO").font(.caption.weight(.bold)).foregroundStyle(.blue).frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
    }

    private func featureRow(_ name: String, free: String, pro: String) -> some View {
        HStack {
            Text(name).font(.callout)
            Spacer()
            Text(free).font(.caption).foregroundStyle(.secondary).frame(width: 80).multilineTextAlignment(.center)
            HStack(spacing: 4) {
                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.blue)
                Text(pro).font(.caption.weight(.medium)).foregroundStyle(.blue)
            }
            .frame(width: 80)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 16)
        }
    }

    // MARK: - 購入ボタン

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if viewModel.products.isEmpty {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.products, id: \.id) { product in
                    purchaseButton(for: product)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("購入を復元する") {
                Task { await viewModel.restorePurchases() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isPurchasing)
        }
    }

    private func purchaseButton(for product: Product) -> some View {
        Button {
            Task { await viewModel.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.callout.weight(.semibold))
                    Text(product.description)
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                if viewModel.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(product.displayPrice)
                        .font(.callout.weight(.bold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(viewModel.isPurchasing)
    }

    // MARK: - デバッグ: PROを強制有効化

    #if DEBUG
    @Environment(AppState.self) private var appState

    private var debugSection: some View {
        VStack(spacing: 8) {
            Divider()
            Toggle(isOn: Binding(
                get: { appState.subscriptionTier == .pro },
                set: { appState.subscriptionTier = $0 ? .pro : .free }
            )) {
                Label("【DEBUG】PROを有効にする", systemImage: "wrench.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 4)
        }
    }
    #endif

    // MARK: - フッター

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("予定データはiPhoneの外には送信されません。")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("購入はApple IDに紐付けられます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - 成功オーバーレイ

    private func successOverlay(_ message: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text(message)
                    .font(.callout.weight(.medium))
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                viewModel.successMessage = nil
                dismiss()
            }
        }
    }
}
