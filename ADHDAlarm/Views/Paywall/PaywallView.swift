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
            icon: "bell.badge.fill",
            color: .orange,
            title: "予定に、もっと早く気づける",
            detail: "大事な予定の前に、複数回のお知らせで気づきやすくなります。"
        ),
        Benefit(
            icon: "calendar.badge.plus",
            color: .blue,
            title: "いつものカレンダーを、そのまま使いやすく",
            detail: "カレンダーを選んで予定を取り込めるので、普段の流れのまま使えます。"
        ),
        Benefit(
            icon: "person.2.fill",
            color: .green,
            title: "家族にサポートしてもらいやすくなる",
            detail: "どちらか1人がPROなら、家族との連携機能を使えます。"
        )
    ]

    static let detailSections: [BenefitSection] = [
        BenefitSection(title: "本人にうれしいこと", items: [
            Benefit(
                icon: "bell.badge.fill",
                color: .orange,
                title: "事前にお知らせ",
                detail: "大事な予定の前に、複数回のお知らせで気づきやすくなります。"
            ),
            Benefit(
                icon: "calendar",
                color: .blue,
                title: "カレンダーを選べる",
                detail: "追加先のカレンダーを自由に選べるので、予定の整理がしやすくなります。"
            ),
            Benefit(
                icon: "calendar.badge.plus",
                color: .blue,
                title: "Appleカレンダーから取り込める",
                detail: "iPhoneのカレンダーにある予定を、ワンタップでアラームに変換できます。"
            ),
            Benefit(
                icon: "waveform.badge.mic",
                color: .purple,
                title: "家族の生声アラーム",
                detail: "大切な人の声を録音して、お薬や通院のアラーム音に設定できます。"
            )
        ]),
        BenefitSection(title: "家族にうれしいこと", items: [
            Benefit(
                icon: "paperplane.fill",
                color: .green,
                title: "家族から予定を送ってもらえる",
                detail: "お薬や通院の予定を、家族がワンタップで送れるようになります。"
            ),
            Benefit(
                icon: "phone.badge.waveform.fill",
                color: .red,
                title: "異変を家族へ自動でお知らせ",
                detail: "アラームが5分止まらないとき、家族がすぐ気づきやすくなります。"
            )
        ])
    ]

    static let personSupport = PaywallVariant(
        imageName: "paywall_elderly_care",
        imageFallbackEmoji: "🗓️🦉",
        heroBackground: [Color.orange.opacity(0.25), Color.yellow.opacity(0.15)],
        headline: "大事な予定に、\nもっと早く気づける。",
        subheadline: "予定の前に早めに気づけて、いつものカレンダーもそのまま使えます。家族にも頼りやすくなります。",
        painHeader: "こんなこと、ありませんか？",
        painPoints: [
            "予定に気づくのが直前になりがち",
            "通院やお薬をうっかり忘れてしまう",
            "家族に頼りたいけど、毎回お願いするのは気が引ける"
        ]
    )
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

    // MARK: - ヒーローセクション（画面上部1/3）

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
        .frame(height: 280)
    }

    @ViewBuilder
    private var heroImage: some View {
        if UIImage(named: variant.imageName) != nil {
            Image(variant.imageName)
                .resizable()
                .scaledToFill()
        } else {
            // 画像未登録時: グラデーション + 絵文字
            LinearGradient(
                colors: variant.heroBackground,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Text(variant.imageFallbackEmoji)
                    .font(.system(size: 110))
                    .padding(.top, 50)
            }
        }
    }

    // MARK: - コンテンツ（ヘッドライン → ペイン → 価値3つ → OR説明 → 詳細 → 価格）

    private var contentSection: some View {
        VStack(spacing: 28) {
            headlineSection
            painSection
            benefitsSection
            orRuleSection
            supportMessageSection
            detailSection
            pricingSection
            legalSection
            #if DEBUG
            debugSection
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    // ヘッドライン
    private var headlineSection: some View {
        VStack(spacing: 10) {
            Text(variant.headline)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(variant.subheadline)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // こんな経験ありませんか？（共感ゾーン）
    private var painSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(variant.painHeader, systemImage: "questionmark.bubble.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(variant.painPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 10) {
                        Text("😔").font(.body)
                        Text(point)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // 本人向けの価値3つ
    private var benefitsSection: some View {
        let benefits = PaywallVariant.personMainBenefits
        return VStack(alignment: .leading, spacing: 4) {
            Label("PROでできること", systemImage: "star.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            ForEach(benefits.indices, id: \.self) { i in
                let b = benefits[i]
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: b.icon)
                        .font(.title3)
                        .foregroundStyle(b.color)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(b.title)
                            .font(.callout.weight(.semibold))
                        Text(b.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 8)

                if i < benefits.count - 1 {
                    Divider().padding(.leading, 46)
                }
            }
        }
    }

    private var orRuleSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("本人か家族、どちらか1人がPROなら、連携機能が使えます。")
                    .font(.callout.weight(.semibold))
                Text("あなたがPROでも、家族は予定送信や見守りのメリットを受けられます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var supportMessageSection: some View {
        Text("ひとりで抱えず、家族にサポートしてもらいやすくなります。")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var detailSection: some View {
        DisclosureGroup(isExpanded: $isDetailExpanded) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(PaywallVariant.detailSections.indices, id: \.self) { sectionIndex in
                    let section = PaywallVariant.detailSections[sectionIndex]
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(section.items.indices, id: \.self) { itemIndex in
                            let item = section.items[itemIndex]
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.callout)
                                    .foregroundStyle(item.color)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.callout.weight(.semibold))
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                comparisonSection
            }
            .padding(.top, 12)
        } label: {
            Text("くわしく見る")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))

            comparisonRow("本人向け: マナーモード貫通アラーム", free: true,  pro: true)
            comparisonRow("本人向け: 予定の音声入力（マイク）", free: true,  pro: true)
            comparisonRow("本人向け: 事前通知",               free: false, pro: true)
            comparisonRow("本人向け: カレンダー自由選択",      free: false, pro: true)
            comparisonRow("本人向け: Appleカレンダー取り込み", free: false, pro: true)
            comparisonRow("本人向け: 家族の生声アラーム",      free: false, pro: true)
            comparisonRow("家族向け: SOS自動通知（見守り）",   free: false, pro: true)
            comparisonRow("連携: 家族から予定を送ってもらう",  free: false, pro: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
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
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider().padding(.leading, 14) }
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
                        Text("7日間の無料体験。いつでもキャンセル可能。")
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
        .padding(.top, 56)
        .padding(.trailing, 20)
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
                        Text("0円で7日間試す")
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
                    Text("7日間無料、その後 \(product.displayPrice)/\(period)。いつでもキャンセル可能。")
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
