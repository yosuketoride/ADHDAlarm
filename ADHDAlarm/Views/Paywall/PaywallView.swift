import SwiftUI
import StoreKit

// MARK: - PaywallView（v2デザイン）

struct PaywallView: View {
    @Environment(StoreKitService.self) private var storeKit
    @Environment(AppState.self) private var appState
    @State private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String? = nil

    @MainActor
    init(viewModel: PaywallViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? PaywallViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                heroSection
                comparisonSection
                pricingSection
                legalSection
                #if DEBUG
                debugSection
                #endif
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ctaSection
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .overlay {
            if let msg = viewModel.successMessage {
                successOverlay(msg)
            }
        }
        .task {
            viewModel.bindIfNeeded(storeKit: storeKit, appState: appState)
            await viewModel.loadIfNeeded()
            if selectedProductID == nil {
                selectedProductID = sortedProducts.first?.id
            }
        }
    }

    // MARK: - ヒーローセクション

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            // フクロウ画像
            ZStack(alignment: .bottom) {
                Image(UIImage(named: "OwlIcon") != nil ? "OwlIcon" : "OwlIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

                // 7日間無料バッジ
                Text("7日間無料でお試しできます")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.owlAmber)
                    .clipShape(Capsule())
                    .offset(y: Spacing.md)
            }
            .padding(.bottom, Spacing.md)

            // タイトル
            Text("もっと便利に、もっと安心に")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 機能比較テーブル

    private var comparisonSection: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("機能")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("無料")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 48)
                Text("PRO")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.owlAmber)
                    .frame(width: 48)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color(.tertiarySystemBackground))

            comparisonRow("マナーモード貫通アラーム", free: true,  pro: true)
            comparisonRow("カレンダー選択",           free: false, pro: true)
            comparisonRow("事前通知を複数回設定",     free: false, pro: true)
            comparisonRow("音声キャラの切り替え",     free: false, pro: true)
            comparisonRow("聞き取りやすいこえ",       free: false, pro: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.secondary.opacity(0.2), lineWidth: BorderWidth.thin)
        )
    }

    private func comparisonRow(_ name: String, free: Bool, pro: Bool) -> some View {
        HStack {
            Text(name)
                .font(.callout)
                .layoutPriority(1)
            Spacer()
            // 無料列
            Group {
                if free {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.statusSuccess)
                } else {
                    Image(systemName: "minus")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48)
            // PRO列
            Group {
                if pro {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.statusSuccess)
                } else {
                    Image(systemName: "minus")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, Spacing.md)
        }
    }

    // MARK: - 価格セクション

    private var pricingSection: some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.isLoading {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
            } else if !viewModel.products.isEmpty {
                ForEach(sortedProducts, id: \.id) { product in
                    productCard(product)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// 年額 → 月額 → 買い切りの順に並べ替え
    private var sortedProducts: [Product] {
        viewModel.products.sorted { a, b in
            productSortOrder(a) < productSortOrder(b)
        }
    }

    private func productSortOrder(_ product: Product) -> Int {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year:  return 0
        case .month: return 1
        default:     return 2
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isYearly  = product.subscription?.subscriptionPeriod.unit == .year
        let isMonthly = product.subscription?.subscriptionPeriod.unit == .month
        let isSelected = selectedProductID == product.id

        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: Spacing.md) {
                // 選択インジケーター
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.owlAmber : Color.secondary.opacity(0.4),
                                lineWidth: BorderWidth.thick)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.owlAmber)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Spacing.sm) {
                        Text(isYearly ? "年額プラン" : isMonthly ? "月額プラン" : "買い切りプラン")
                            .font(.callout.weight(.semibold))
                        if isYearly {
                            Text("おすすめ")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, 3)
                                .background(Color.owlAmber)
                                .clipShape(Capsule())
                        }
                    }
                    if isYearly {
                        Text("月あたり約\(monthlyEquivalent(for: product))　2ヶ月分お得 ✨")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if isMonthly {
                        Text("いつでもキャンセル可")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("一度の支払いでずっと使える")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.callout.weight(.bold))
                    Text(isYearly ? "/ 年" : isMonthly ? "/ 月" : "一度きり")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(isSelected ? Color.owlAmber.opacity(0.08) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(isSelected ? Color.owlAmber : Color.clear, lineWidth: BorderWidth.thick)
                    )
            )
            .foregroundStyle(.primary)
        }
    }

    /// 年間価格を12分割して月あたり表示
    private func monthlyEquivalent(for product: Product) -> String {
        let monthly = product.price / Decimal(12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = product.priceFormatStyle.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: monthly as NSDecimalNumber) ?? product.displayPrice
    }

    // MARK: - 法的セクション

    private var legalSection: some View {
        VStack(spacing: Spacing.sm) {
            Button("すでに購入済みの方はこちら（購入を復元する）") {
                Task { await viewModel.restorePurchases() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isPurchasing)

            HStack(spacing: Spacing.md) {
                if let url = URL(string: Constants.LegalURL.terms) {
                    Link("利用規約", destination: url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("・")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let url = URL(string: Constants.LegalURL.privacy) {
                    Link("プライバシー", destination: url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("購入はApple IDに紐付けられます。自動更新はiOSの設定からいつでも停止できます。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 閉じるボタン

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(.systemGray), Color(.systemGray4))
        }
        .safeAreaPadding(.top)
        .padding(.top, Spacing.sm)
        .padding(.trailing, Spacing.md)
    }

    // MARK: - 購入CTAボタン（画面下部固定）

    private var ctaSection: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                guard let id = selectedProductID,
                      let product = viewModel.products.first(where: { $0.id == id }) else { return }
                Task { await viewModel.purchase(product) }
            } label: {
                Group {
                    if viewModel.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("7日間無料でお試しする")
                            .font(.title3.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.primary)
            }
            .buttonStyle(.large(background: Color.owlAmber))
            .disabled(viewModel.isPurchasing || viewModel.products.isEmpty)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            // Apple審査要件: ボタン直下に価格・自動更新を明記
            if let id = selectedProductID,
               let product = viewModel.products.first(where: { $0.id == id }) {
                let periodText: String? = {
                    switch product.subscription?.subscriptionPeriod.unit {
                    case .year:  return "年"
                    case .month: return "月"
                    default:     return nil
                    }
                }()
                if let periodText {
                    Text("7日間無料、その後 \(product.displayPrice)/\(periodText)。いつでもキャンセル可能。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                } else {
                    Text("一度の購入で永久にご利用いただけます（\(product.displayPrice)）。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }
            }
        }
        .padding(.bottom, Spacing.sm)
        .background(.regularMaterial)
    }

    // MARK: - 購入成功オーバーレイ

    private func successOverlay(_ message: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.statusSuccess)
                Text(message)
                    .font(.callout.weight(.medium))
            }
            .padding(Spacing.lg)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            viewModel.successMessage = nil
            dismiss()
        }
    }

    // MARK: - デバッグ: PRO強制有効化

    #if DEBUG
    private var debugSection: some View {
        VStack(spacing: Spacing.sm) {
            Divider()
            Toggle(isOn: Binding(
                get: { appState.subscriptionTier == .pro },
                set: { appState.subscriptionTier = $0 ? .pro : .free }
            )) {
                Label("【DEBUG】PROを有効にする", systemImage: "wrench.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, Spacing.xs)
        }
    }
    #endif
}
