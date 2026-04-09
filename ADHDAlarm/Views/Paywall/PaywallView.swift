import SwiftUI
import StoreKit
import UIKit

// MARK: - 本人向けPaywallコピー定義

fileprivate struct PaywallVariant {
    let imageName: String
    let imageFallbackEmoji: String
    let heroBackground: [Color]
    let headline: String
    let subheadline: String
    let painHeader: String
    let painPoints: [String]

    // 本人向けPaywall専用の表示モデル。
    // FamilyPaywallView とは訴求順と詳細構成が異なるため、あえて別定義にしている。
    struct Benefit {
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    struct BenefitSection {
        let title: String
        let items: [Benefit]
    }

    static let personMainBenefits: [Benefit] = [
        Benefit(
            icon: "bell.badge",
            color: .secondary,
            title: "大事な予定に、確実に気づける",
            detail: "何分前にアラームを鳴らすか、予定ごとに設定できます。複数の設定も可能です。"
        ),
        Benefit(
            icon: "calendar.badge.plus",
            color: .secondary,
            title: "カレンダーを、そのままアラーム予定に",
            detail: "カレンダー上の予定をワンタップでアラームに変換できます。"
        ),
        Benefit(
            icon: "calendar",
            color: .secondary,
            title: "仕事とプライベート、どちらのカレンダーにも",
            detail: "任意のカレンダーに、このアプリで作るアラームの予定を書き込めます。"
        ),
        Benefit(
            icon: "waveform.badge.mic",
            color: .secondary,
            title: "家族の生声アラーム",
            detail: "家族の声を録音して、アラームとして鳴らせます"
        )     
    ]

    static let detailSections: [BenefitSection] = [
        // BenefitSection(title: "本人にうれしいこと", items: [
        //     Benefit(
        //         icon: "alarm",
        //         color: .secondary,
        //         title: "大事な予定に、確実に気づける",
        //         detail: "何分前にアラームを鳴らすか、予定ごとに設定できます。複数の設定も可能です。"
        //     ),
        //     Benefit(
        //         icon: "calendar.badge.plus",
        //         color: .secondary,
        //         title: "カレンダーを、そのままアラーム予定に",
        //         detail: "カレンダー上の予定をワンタップでアラームに変換できます。"
        //     ),
        //     Benefit(
        //         icon: "calendar",
        //         color: .secondary,
        //         title: "仕事とプライベート、どちらのカレンダーにも",
        //         detail: "任意のカレンダーに、このアプリで作るアラームの予定を書き込めます。"
        //     )
        // ]),
        BenefitSection(title: "家族にうれしいこと", items: [
            Benefit(
                icon: "paperplane",
                color: .secondary,
                title: "遠隔で予定を入れて見守れる",
                detail: "家族が、お薬・病院などの予定をあなたのスマホへ送れるようになります。"
            ),
            Benefit(
                icon: "phone.badge.waveform",
                color: .secondary,
                title: "異変をLINEでお知らせ",
                detail: "アラームが5分止まらないとき、家族がすぐ気づきやすくなります。"
            ),
            Benefit(
                icon: "list.bullet.rectangle",
                color: .secondary,
                title: "7日間の記録を見守れる",
                detail: "予定の完了やお休みの記録を、家族がまとめて振り返れます。"
            )
        ])
    ]

    static let personSupport = PaywallVariant(
        imageName: "owl_stage0_normal",
        imageFallbackEmoji: "🦉",
        heroBackground: [Color.owlAmber.opacity(0.16), Color.owlBrown.opacity(0.08)],
        headline: "大事な予定に、\n確実に気づける",
        subheadline: "うっかり忘れる予定を、強烈なアラーム通知で支えます。",
        painHeader: "こんなこと、ありませんか？",
        painPoints: [
            "予定に気づくのが直前になりがち",
            "通院やお薬をうっかり忘れてしまう",
            "家族に頼りたいけど、毎回お願いするのは気が引ける"
        ]
    )
}

#Preview("本人向けPaywall") {
    PaywallView(viewModel: PaywallViewModel())
        .environment(StoreKitService())
        .environment(AppState())
}

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(StoreKitService.self) private var storeKit
    @Environment(AppState.self) private var appState
    @State var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var variant: PaywallVariant = .personSupport
    @State private var selectedProductID: String? = nil
    @State private var isDetailExpanded = false

    private enum Layout {
        static let heroHeight: CGFloat = 160
        static let heroEmojiSize: CGFloat = 96
    }

    @MainActor
    init(viewModel: PaywallViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? PaywallViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                contentSection
            }
        }
        .ignoresSafeArea(edges: .top)
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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                heroImage
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height)
                    .clipped()

                // 下部グラデーション: 画像をコンテンツへ自然に繋げる
                LinearGradient(
                    colors: [.clear, Color(.systemBackground)],
                    startPoint: UnitPoint(x: 0.5, y: 0.4),
                    endPoint: .bottom
                )
                .frame(height: 120)
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(height: Layout.heroHeight)
    }

    @ViewBuilder
    private var heroImage: some View {
        LinearGradient(
            colors: variant.heroBackground,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            if UIImage(named: variant.imageName) != nil {
                Image(variant.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
            } else {
                Text(variant.imageFallbackEmoji)
                    .font(.system(size: Layout.heroEmojiSize))
                    .padding(.top, Spacing.xl)
            }
        }
    }

    // MARK: - コンテンツ（ヘッドライン → ペイン → 価値3つ → OR説明 → 詳細 → 価格）

    private var contentSection: some View {
        VStack(spacing: Spacing.lg) {
            headlineSection
            painSection
            transitionHintSection
            benefitsSection
            // supportMessageSection
            orRuleSection
            detailSection
            pricingSection
            legalSection
            #if DEBUG
            debugSection
            #endif
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.lg)
    }

    // ヘッドライン
    private var headlineSection: some View {
        VStack(spacing: Spacing.sm) {
            Text(variant.headline)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(variant.subheadline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // 共感ゾーン
    private var painSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(variant.painHeader, systemImage: "questionmark.bubble.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(variant.painPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: IconSize.sm))
                            .foregroundStyle(.secondary)
                        Text(point)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
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

    // 本人向けの価値3つ
    private var benefitsSection: some View {
        let benefits = PaywallVariant.personMainBenefits
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("PROでできること", systemImage: "star.fill")
                .font(.callout.weight(.bold))
                .foregroundStyle(Color.owlBrown)
                .symbolRenderingMode(.monochrome)
                .padding(.bottom, Spacing.xs)

            ForEach(benefits.indices, id: \.self) { i in
                let b = benefits[i]
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: b.icon)
                        .font(.system(size: IconSize.sm, weight: .semibold))
                        .foregroundStyle(b.color)
                        .frame(width: IconSize.md)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(b.title)
                            .font(.callout.weight(.semibold))
                        Text(b.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, Spacing.sm)

                if i < benefits.count - 1 {
                    Divider().padding(.leading, IconSize.md + Spacing.sm)
                }
            }
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

    private var orRuleSection: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "link")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("本人か家族、どちらか1人がPROなら、連携機能が使えます。")
                    .font(.caption.weight(.semibold))
                // Text("家族への予定送信や、アラームが止まらないときのお知らせも使えます。")
                //     .font(.caption2)
                //     .foregroundStyle(.secondary)
                //     .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var supportMessageSection: some View {
        Text("ひとりで抱え込まず、必要なときは家族にも手伝ってもらえます。")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var detailSection: some View {
        DisclosureGroup(isExpanded: $isDetailExpanded) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(PaywallVariant.detailSections.indices, id: \.self) { sectionIndex in
                    let section = PaywallVariant.detailSections[sectionIndex]
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(section.items.indices, id: \.self) { itemIndex in
                            let item = section.items[itemIndex]
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: item.icon)
                                    .font(.system(size: IconSize.sm, weight: .semibold))
                                    .foregroundStyle(item.color)
                                    .frame(width: IconSize.md)
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(item.title)
                                        .font(.callout.weight(.semibold))
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, Spacing.xs)
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

    // 無料 vs PRO 比較表（詳細の中で表示）
    private var comparisonSection: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("機能").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("無料").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 52)
                Text("PRO").font(.caption.weight(.bold)).foregroundStyle(.blue).frame(width: 52)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.thinMaterial)

            comparisonRow("あなた向け: マナーモード貫通アラーム", free: true,  pro: true)
            comparisonRow("あなた向け: 予定の音声入力（マイク）", free: true,  pro: true)
            comparisonRow("あなた向け: 複数の事前通知",               free: false, pro: true)
            comparisonRow("あなた向け: カレンダー自由選択",      free: false, pro: true)
            comparisonRow("あなた向け: カレンダー取り込み", free: false, pro: true)
            comparisonRow("あなた向け: 家族の生声アラーム",      free: false, pro: true)
            comparisonRow("家族向け: SOS自動通知（見守り）",   free: false, pro: true)
            comparisonRow("連携: 家族から予定を送ってもらう",  free: false, pro: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.secondary.opacity(0.2), lineWidth: BorderWidth.thin)
        )
    }

    private func comparisonRow(_ name: String, free: Bool, pro: Bool) -> some View {
        HStack {
            Text(name).font(.caption).fixedSize(horizontal: false, vertical: true)
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
        .overlay(alignment: .bottom) { Divider().padding(.leading, Spacing.md) }
    }

    // MARK: - 価格セクション

    private var pricingSection: some View {
        VStack(spacing: 12) {
            if viewModel.isLoading {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if viewModel.products.isEmpty {
                EmptyView()
            } else {
                ForEach(sortedProducts, id: \.id) { product in
                    productCard(product)
                }

                if sortedProducts.contains(where: { $0.subscription != nil }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("14日間の無料体験。いつでもキャンセル可能。")
                            .font(.callout.weight(.medium))
                    }
                    .padding(.top, 4)
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
        let planType = planType(for: product)
        let isSelected = selectedProductID == product.id

        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: 0) {
                // 選択インジケーター
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.trailing, 14)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(planType.label)
                            .font(.callout.weight(.semibold))
                        if let badge = planType.badge {
                            Text(badge.text)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(badge.color)
                                .clipShape(Capsule())
                        }
                    }
                    if let note = planType.note(product) {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.callout.weight(.bold))
                    Text(planType.priceUnit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color.secondary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
            .foregroundStyle(.primary)
        }
    }

    // MARK: - プランタイプ分類

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
                badge: PlanBadge(text: "おすすめ", color: .orange),
                note: { p in "1ヶ月あたり約\(monthlyEquivalent(for: p))　コーヒー1杯分" }
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
                badge: PlanBadge(text: "ずっと使える", color: .purple),
                note: { _ in "一度の支払いで、ずっとPROが使えます。" }
            )
        }
    }

    /// 年間価格を12分割して月あたり表示（例: ¥149）
    private func monthlyEquivalent(for product: Product) -> String {
        let monthly = product.price / Decimal(12)
        let intValue = (monthly as NSDecimalNumber).intValue
        return "¥\(intValue)"
    }

    // MARK: - 法的セクション（App Store審査必須）

    private var legalSection: some View {
        VStack(spacing: 10) {
            Button("購入を復元する") {
                Task { await viewModel.restorePurchases() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isPurchasing)

            HStack(spacing: 20) {
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

            Text("購入はApple IDに紐付けられます。自動更新はiOSの設定からいつでも停止できます。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 閉じるボタン（ヒーロー上に重ねる）

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.black.opacity(0.35))
        }
        .padding(.top, Spacing.xl + Spacing.md)
        .padding(.trailing, Spacing.md)
    }

    // MARK: - スティッキーCTAボタン（画面下部に固定）

    private var ctaSection: some View {
        VStack(spacing: 6) {
            Button {
                guard let id = selectedProductID,
                      let product = viewModel.products.first(where: { $0.id == id }) else { return }
                Task { await viewModel.purchase(product) }
            } label: {
                Group {
                    if viewModel.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("14日間無料で試す")
                            .font(.title3.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(viewModel.isPurchasing || viewModel.products.isEmpty)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Apple審査要件: ボタン直下に価格・自動更新を明記
            if let id = selectedProductID,
               let product = viewModel.products.first(where: { $0.id == id }) {
                let period: String? = {
                    switch product.subscription?.subscriptionPeriod.unit {
                    case .year:  return "年"
                    case .month: return "月"
                    default:     return nil
                    }
                }()
                if let period {
                    Text("14日間無料、その後 \(product.displayPrice)/\(period)。いつでもキャンセル可能。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else {
                    Text("一度の購入で永久にご利用いただけます（\(product.displayPrice)）。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 4)
        .background(.regularMaterial)
    }

    // MARK: - 購入成功オーバーレイ

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

    // MARK: - デバッグ: PRO強制有効化

    #if DEBUG
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
}
