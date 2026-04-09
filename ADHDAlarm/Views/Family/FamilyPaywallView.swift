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
        let emoji: String
        let title: String
        let detail: String
        let accent: Color
    }

    private let mainBenefits: [Benefit] = [
        Benefit(
            emoji: "📨",
            title: "予定をワンタップで届けられる",
            detail: "お薬や通院の予定を、相手のiPhoneへそのまま送れます。",
            accent: .owlAmber
        ),
        Benefit(
            emoji: "🆘",
            title: "5分反応がなければ、すぐ気づける",
            detail: "アラームが止まらないとき、LINEですぐ気づきやすくなります。",
            accent: .statusDanger
        ),
        Benefit(
            emoji: "📋",
            title: "7日分の様子を、まとめて確認できる",
            detail: "完了やお休みの記録をまとめて振り返れます。",
            accent: .blue
        )
    ]

    private let detailSections: [(title: String, benefits: [Benefit])] = [
        (
            title: "家族にうれしいこと",
            benefits: [
                Benefit(
                    emoji: "📨",
                    title: "予定をワンタップで送れる",
                    detail: "お薬・病院・ご飯などを、相手のスマホにアラームとして届けられます。",
                    accent: .owlAmber
                ),
                Benefit(
                    emoji: "🆘",
                    title: "異変をLINEでお知らせ",
                    detail: "アラームが5分止まらないとき、LINEで気づきやすくお知らせします。",
                    accent: .statusDanger
                ),
                Benefit(
                    emoji: "📋",
                    title: "7日間の記録を見守れる",
                    detail: "完了・スキップの履歴をまとめて確認できます。",
                    accent: .blue
                ),
                Benefit(
                    emoji: "🕐",
                    title: "Last Seen を確認できる",
                    detail: "いつ確認したかが分かるので、様子をつかみやすくなります。",
                    accent: .blue
                )
            ]
        ),
        (
            title: "本人にうれしいこと",
            benefits: [
                Benefit(
                    emoji: "🔔",
                    title: "事前にお知らせ",
                    detail: "予定の前に早めに気づきやすくなります。",
                    accent: .orange
                ),
                Benefit(
                    emoji: "📅",
                    title: "カレンダーを選べる",
                    detail: "追加先のカレンダーを自由に選べるので、予定の整理がしやすくなります。",
                    accent: .green
                ),
                Benefit(
                    emoji: "🗓️",
                    title: "Appleカレンダーから取り込める",
                    detail: "iPhoneの予定をワンタップでアラームに変換できます。",
                    accent: .green
                )
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                heroSection
                painSection
                benefitsSection
                orRuleSection
                supportMessageSection
                detailSection
                Spacer(minLength: Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xl)
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
        VStack(spacing: Spacing.md) {
            Image("owl_stage0_normal")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)

            Text("離れていても、\nさりげなく支えられます")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("予定を送り、異変にも気づける。毎日の見守りが少しラクになります。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [Color.owlAmber.opacity(0.18), Color.statusDanger.opacity(0.08)],
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
        .padding(Spacing.lg)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private func painRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("😔")
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("PROでできること", systemImage: "star.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(mainBenefits) { benefit in
                benefitCard(benefit)
            }
        }
    }

    private func benefitCard(_ benefit: Benefit) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(benefit.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 3) {
                Text(benefit.title)
                    .font(.body.weight(.semibold))
                Text(benefit.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(benefit.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private var orRuleSection: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "link.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("本人か家族、どちらか1人がPROなら、連携機能が使えます。")
                    .font(.callout.weight(.semibold))
                Text("あなたがPROでも、本人側に便利機能のメリットがあります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.lg)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
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
                            benefitCard(benefit)
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
        .padding(Spacing.lg)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
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
                    .frame(minHeight: 56)
                    .background(Color.owlAmber, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            }
            .buttonStyle(.plain)

            Button("あとで") {
                dismiss()
            }
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .background(.ultraThinMaterial)
    }
}
