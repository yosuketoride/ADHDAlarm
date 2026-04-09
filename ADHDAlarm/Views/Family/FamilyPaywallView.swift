import SwiftUI

struct FamilyPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showStoreKitPaywall = false
    @State private var isDetailExpanded = false

    /// 外から上書き可能（省略時は PaywallView を自動的に開く）
    var onUpgradeTapped: (() -> Void)? = nil

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
            title: "予定をワンタップで届けられる",
            detail: "お薬や通院の予定を、相手のiPhoneへそのまま送れます。",
            accent: .secondary
        ),
        Benefit(
            icon: "phone.badge.waveform",
            title: "アラームが止まらないとき、LINEで気づける",
            detail: "アラームが止まらないとき、LINEですぐ気づきやすくなります。",
            accent: .secondary
        ),
        Benefit(
            icon: "list.bullet.rectangle",
            title: "7日分の様子を、まとめて確認できる",
            detail: "完了やお休みの記録をまとめて振り返れます。",
            accent: .secondary
        )
    ]

    private let detailSections: [(title: String, benefits: [Benefit])] = [
        (
            title: "家族にうれしいこと",
            benefits: [
                Benefit(
                    icon: "paperplane",
                    title: "予定をワンタップで送れる",
                    detail: "お薬・病院・ご飯などを、相手のスマホにアラームとして届けられます。",
                    accent: .secondary
                ),
                Benefit(
                    icon: "phone.badge.waveform",
                    title: "異変をLINEでお知らせ",
                    detail: "アラームが5分止まらないとき、LINEで気づきやすくお知らせします。",
                    accent: .secondary
                ),
                Benefit(
                    icon: "list.bullet.rectangle",
                    title: "7日間の記録を見守れる",
                    detail: "完了・スキップの履歴をまとめて確認できます。",
                    accent: .secondary
                ),
                Benefit(
                    icon: "clock",
                    title: "Last Seen を確認できる",
                    detail: "いつ確認したかが分かるので、様子をつかみやすくなります。",
                    accent: .secondary
                )
            ]
        ),
        (
            title: "本人にうれしいこと",
            benefits: [
                Benefit(
                    icon: "bell.badge",
                    title: "事前にお知らせ",
                    detail: "予定の前に早めに気づきやすくなります。",
                    accent: .secondary
                ),
                Benefit(
                    icon: "calendar",
                    title: "カレンダーを選べる",
                    detail: "追加先のカレンダーを自由に選べるので、予定の整理がしやすくなります。",
                    accent: .secondary
                ),
                Benefit(
                    icon: "calendar.badge.plus",
                    title: "Appleカレンダーから取り込める",
                    detail: "iPhoneの予定をワンタップでアラームに変換できます。",
                    accent: .secondary
                )
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                heroSection
                painSection
                benefitsSection
                orRuleSection
                supportMessageSection
                detailSection
                Spacer(minLength: Spacing.lg)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ctaSection
        }
        .sheet(isPresented: $showStoreKitPaywall) {
            PaywallView()
        }
    }

    private var heroSection: some View {
        VStack(spacing: Spacing.sm) {
            Image("owl_stage0_normal")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)

            Text("離れていても、\nご家族の予定を届けて見守れる")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("通院やお薬の予定を送り、もしものときも気づきやすくなります")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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

            painRow("ちゃんとお薬を飲めているか心配")
            painRow("通院の日を忘れていないか不安")
            painRow("何かあったとき、すぐ気づけないのがこわい")
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .symbolRenderingMode(.monochrome)
                .padding(.bottom, Spacing.xs)

            ForEach(Array(mainBenefits.enumerated()), id: \.element.id) { index, benefit in
                benefitRow(benefit)

                if index < mainBenefits.count - 1 {
                    Divider().padding(.leading, IconSize.md + Spacing.sm)
                }
            }
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.owlAmber.opacity(0.22), lineWidth: BorderWidth.thin)
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
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "link")
                .font(.system(size: IconSize.sm, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("本人か家族、どちらか1人がPROなら、連携機能が使えます。")
                    .font(.callout.weight(.semibold))
                Text("予定を送ることや、アラームが止まらないときのLINE通知も使えます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private var supportMessageSection: some View {
        Text("見守るだけでなく、あなたから予定を届けて支えられます。")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
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
            }
            .padding(.top, Spacing.md)
        } label: {
            Text("くわしく見る")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private var ctaSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                if let callback = onUpgradeTapped {
                    callback()
                } else {
                    showStoreKitPaywall = true
                }
            } label: {
                Text("7日間無料で始める（月額880円）")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ComponentSize.primary)
                    .background(Color.owlAmber, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            }
            .buttonStyle(.plain)

            Button("あとで") {
                dismiss()
            }
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(minHeight: ComponentSize.small)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .background(.ultraThinMaterial)
    }
}
