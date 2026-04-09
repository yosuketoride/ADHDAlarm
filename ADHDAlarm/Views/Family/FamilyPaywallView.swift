import SwiftUI
import StoreKit

struct FamilyPaywallView: View {
    @Environment(StoreKitService.self) private var storeKit
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: PaywallViewModel
    @State private var selectedProductID: String? = nil
    @State private var isDetailExpanded = false

    /// 初回フローでは無料ペアリングへ進む。通常のシート表示では nil のままで閉じる。
    var onContinueWithoutUpgrade: (() -> Void)? = nil

    // 家族向けPaywall専用の表示モデル。
    // PaywallView とは訴求順と詳細構成が異なるため、共通化せず別定義にしている。
    private struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let accent: Color
    }

    private let mainBenefits: [Benefit] = [
        Benefit(
            icon: "paperplane",
            title: "遠隔で予定を入れて見守れる",
            detail: "あなたのスマホから、お薬・病院などの予定を、ご家族のスマホにアラームとして届けられます。",
            accent: .secondary
        ),
        Benefit(
            icon: "phone.badge.waveform",
            title: "異変をLINEでお知らせ",
            detail: "アラームが5分止まらないとき、LINEに通知がきます。",
            accent: .secondary
        ),
        Benefit(
            icon: "list.bullet.rectangle",
            title: "7日間の記録を見守れる",
            detail: "ご家族の予定の、完了やお休みの記録をまとめて振り返れます。",
            accent: .secondary
        )
    ]

    private let detailSections: [(title: String, benefits: [Benefit])] = [
        (
            title: "ご家族にうれしいこと",
            benefits: [
                Benefit(
                    icon: "alarm",
                    title: "大事な予定に、確実に気づける",
                    detail: "何分前にアラームを鳴らすか、予定ごとに設定できます。複数の設定も可能です。",
                    accent: .secondary
                ),
                Benefit(
                    icon: "calendar.badge.plus",
                    title: "カレンダーを、そのままアラーム予定に",
                    detail: "カレンダー上の予定をワンタップでアラームに変換できます。",
                    accent: .secondary
                ),
                Benefit(
                    icon: "calendar",
                    title: "仕事とプライベート、どちらのカレンダーにも",
                    detail: "任意のカレンダーに、このアプリで作るアラームの予定を書き込めます。",
                    accent: .secondary
                ),
                Benefit(
                    icon: "waveform.badge.mic",
                    title: "お孫さんの生声アラーム",
                    detail: "お孫さんの声を録音して、アラームとして鳴らせます",
                    accent: .secondary
                ),
            ]
        )
    ]

    @MainActor
    init(viewModel: PaywallViewModel? = nil, onContinueWithoutUpgrade: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel ?? PaywallViewModel())
        self.onContinueWithoutUpgrade = onContinueWithoutUpgrade
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                heroSection
                painSection
                transitionHintSection
                benefitsSection
                orRuleSection
                detailSection
                pricingSection
                legalSection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ctaSection
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

    private var heroSection: some View {
        VStack(spacing: Spacing.sm) {
            Image("owl_stage0_normal")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            Text("離れていても、ご家族のそばに。")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("病院やお薬の予定を作成し、様子を確認することで、ご家族をさりげなく支えられます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(
            LinearGradient(
                colors: [Color.owlAmber.opacity(0.14), Color.owlBrown.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.lg)
        )
    }

    private var painSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("こんな心配、ありませんか？", systemImage: "questionmark.bubble.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            painRow("病院の日を忘れていないか不安")
            painRow("ちゃんとお薬を飲めているか心配")
            painRow("家族に何かあったとき、すぐ気づけないのがこわい")
        }
        .padding(Spacing.md)
        // .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private var transitionHintSection: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.down")
            Text("PROで支えます")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func painRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: IconSize.sm))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("PROでできること", systemImage: "star.fill")
                .font(.callout.weight(.bold))
                .foregroundStyle(Color.owlBrown)
                .symbolRenderingMode(.monochrome)
                .padding(.bottom, Spacing.xs)

            ForEach(Array(mainBenefits.enumerated()), id: \.element.id) { index, benefit in
                benefitRow(benefit)

                if index < mainBenefits.count - 1 {
                    Divider().padding(.leading, IconSize.md + Spacing.sm)
                }
            }

            // Divider()
            //     .padding(.top, Spacing.xs)

            // Text("見守るだけでなく、あなたから予定を届けて支えられます。")
            //     .font(.headline.weight(.bold))
            //     .foregroundStyle(Color.owlBrown)
            //     .fixedSize(horizontal: false, vertical: true)
            //     .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.owlAmber.opacity(0.06))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.owlAmber.opacity(0.42), lineWidth: BorderWidth.thick)
        )
    }

    private func benefitRow(_ benefit: Benefit) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: benefit.icon)
                .font(.system(size: IconSize.sm, weight: .semibold))
                .foregroundStyle(benefit.accent)
                .frame(width: IconSize.md)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(benefit.title)
                    .font(.callout.weight(.semibold))
                Text(benefit.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var orRuleSection: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "link")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("あなたか家族、どちらか1人がPROなら、連携機能が使えます。")
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    private var detailSection: some View {
        DisclosureGroup(isExpanded: $isDetailExpanded) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(Array(detailSections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(section.benefits) { benefit in
                            benefitRow(benefit)
                        }
                    }
                }

                comparisonSection
            }
            .padding(.top, Spacing.md)
        } label: {
            Text("他にも嬉しいこと")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private var comparisonSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("機能")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("無料")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 52)
                Text("PRO")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                    .frame(width: 52)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.thinMaterial)

            comparisonRow("家族向け: マナーモード貫通アラーム", free: true,  pro: true)
            comparisonRow("家族向け: 予定の音声入力（マイク）", free: true,  pro: true)
            comparisonRow("家族向け: 複数の事前通知",               free: false, pro: true)
            comparisonRow("家族向け: カレンダー自由選択",      free: false, pro: true)
            comparisonRow("家族向け: カレンダー取り込み", free: false, pro: true)
            comparisonRow("家族向け: 家族の生声アラーム",      free: false, pro: true)
            comparisonRow("あなた向け: SOS自動通知（見守り）",   free: false, pro: true)
            comparisonRow("連携: あなたから予定を送る",  free: false, pro: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.secondary.opacity(0.2), lineWidth: BorderWidth.thin)
        )
    }

    private func comparisonRow(_ name: String, free: Bool, pro: Bool) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Image(systemName: free ? "checkmark" : "minus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(free ? Color.secondary : Color.secondary.opacity(0.3))
                .frame(width: 52)
            Image(systemName: pro ? "checkmark.circle.fill" : "minus")
                .font(.caption.weight(.bold))
                .foregroundStyle(pro ? Color.blue : Color.secondary.opacity(0.3))
                .frame(width: 52)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.background)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, Spacing.md)
        }
    }

    private var ctaSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                guard let id = selectedProductID,
                      let product = viewModel.products.first(where: { $0.id == id }) else { return }
                Task { await viewModel.purchase(product) }
            } label: {
                Group {
                    if viewModel.isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text(ctaTitle)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(minHeight: ComponentSize.primary)
                .background(Color.owlAmber, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPurchasing || viewModel.products.isEmpty)

            Button(onContinueWithoutUpgrade == nil ? "あとで" : "無料でペアリングだけする") {
                if let onContinueWithoutUpgrade {
                    onContinueWithoutUpgrade()
                } else {
                    dismiss()
                }
            }
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(minHeight: ComponentSize.small)
            .buttonStyle(.plain)

            if let id = selectedProductID,
               let product = viewModel.products.first(where: { $0.id == id }) {
                let period: String? = {
                    switch product.subscription?.subscriptionPeriod.unit {
                    case .year: return "年"
                    case .month: return "月"
                    default: return nil
                    }
                }()
                if let period {
                    Text("14日間無料、その後 \(product.displayPrice)/\(period)。いつでもキャンセルできます。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                } else {
                    Text("一度の購入でずっと使えます（\(product.displayPrice)）。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .background(.ultraThinMaterial)
    }

    private var pricingSection: some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.isLoading {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
            } else if viewModel.products.isEmpty {
                VStack(spacing: Spacing.xs) {
                    Text("価格を読み込み中です")
                        .font(.callout.weight(.semibold))
                    Text("通信状況によって、表示まで少し時間がかかることがあります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            } else {
                Text("プランを選ぶ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(sortedProducts, id: \.id) { product in
                    productCard(product)
                }

                if sortedProducts.contains(where: { $0.subscription != nil }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("14日間の無料体験。いつでもキャンセル可能。")
                            .font(.callout.weight(.medium))
                    }
                    .padding(.top, Spacing.xs)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.statusDanger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var sortedProducts: [Product] {
        viewModel.products.sorted { productSortOrder($0) < productSortOrder($1) }
    }

    private func productSortOrder(_ product: Product) -> Int {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year: return 0
        case .month: return 1
        default: return 2
        }
    }

    private func productCard(_ product: Product) -> some View {
        let planType = planType(for: product)
        let isSelected = selectedProductID == product.id

        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.owlAmber : Color.secondary.opacity(0.4), lineWidth: BorderWidth.thick)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.owlAmber)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.trailing, Spacing.sm)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(planType.label)
                            .font(.callout.weight(.semibold))
                        if let badge = planType.badge {
                            Text(badge.text)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(badge.color, in: Capsule())
                        }
                    }
                    if let note = planType.note(product) {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(product.displayPrice)
                        .font(.callout.weight(.bold))
                    Text(planType.priceUnit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(isSelected ? Color.owlAmber.opacity(0.12) : Color.secondary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(isSelected ? Color.owlAmber : Color.clear, lineWidth: BorderWidth.thick)
                    )
            )
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private struct PlanBadge {
        let text: String
        let color: Color
    }

    private struct PlanType {
        let label: String
        let priceUnit: String
        let badge: PlanBadge?
        let note: (Product) -> String?
    }

    private func planType(for product: Product) -> PlanType {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year:
            return PlanType(
                label: "年間プラン",
                priceUnit: "/ 年",
                badge: PlanBadge(text: "おすすめ", color: .owlAmber),
                note: { p in "1ヶ月あたり約\(monthlyEquivalent(for: p))" }
            )
        case .month:
            return PlanType(
                label: "月額プラン",
                priceUnit: "/ 月",
                badge: nil,
                note: { _ in nil }
            )
        default:
            return PlanType(
                label: "買い切りプラン",
                priceUnit: "一度きり",
                badge: PlanBadge(text: "ずっと使える", color: .owlAmber),
                note: { _ in "一度の支払いで、ずっとPROが使えます。" }
            )
        }
    }

    private func monthlyEquivalent(for product: Product) -> String {
        let monthly = product.price / Decimal(12)
        let intValue = (monthly as NSDecimalNumber).intValue
            return "¥\(intValue)"
    }

    private var ctaTitle: String {
        guard let id = selectedProductID,
              let product = viewModel.products.first(where: { $0.id == id }) else {
            return "14日間無料で始める"
        }

        if let unit = product.subscription?.subscriptionPeriod.unit {
            switch unit {
            case .month:
                return "14日間無料で始める（月額\(product.displayPrice)）"
            case .year:
                return "14日間無料で始める（年額\(product.displayPrice)）"
            default:
                return "14日間無料で始める"
            }
        }

        return "買い切りで始める（\(product.displayPrice)）"
    }

    private var legalSection: some View {
        VStack(spacing: Spacing.sm) {
            Button("購入を復元する") {
                Task { await viewModel.restorePurchases() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isPurchasing)

            HStack(spacing: Spacing.md) {
                if let url = URL(string: Constants.LegalURL.terms) {
                    Link("利用規約", destination: url)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let url = URL(string: Constants.LegalURL.privacy) {
                    Link("プライバシーポリシー", destination: url)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("購入はApple IDに紐づきます。自動更新はiPhoneの設定からいつでも停止できます。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func successOverlay(_ message: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.statusSuccess)
                Text(message)
                    .font(.callout.weight(.medium))
            }
            .padding(Spacing.md)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                viewModel.successMessage = nil
                if let onContinueWithoutUpgrade {
                    onContinueWithoutUpgrade()
                } else {
                    dismiss()
                }
            }
        }
    }
}

#Preview("家族向けPaywall") {
    FamilyPaywallView()
        .environment(StoreKitService())
        .environment(AppState())
}
