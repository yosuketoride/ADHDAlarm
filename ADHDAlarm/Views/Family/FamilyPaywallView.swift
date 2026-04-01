import SwiftUI

struct FamilyPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showStoreKitPaywall = false

    /// 外から上書き可能（省略時は PaywallView を自動的に開く）
    var onUpgradeTapped: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                heroSection
                benefitsSection
                Spacer(minLength: Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ctaSection
        }
        .sheet(isPresented: $showStoreKitPaywall) {
            PaywallView()
        }
    }

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            Text("👨‍👩‍👧")
                .font(.system(size: 56))

            Text("お母さんのことを、もっと近くに感じたい方へ")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("離れていても、気づける安心を見守り機能で届けます。")
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

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            benefitCard(
                emoji: "🆘",
                title: "「アラームが5分止まらない」→ あなたのスマホへ自動お知らせ",
                accent: .statusDanger
            )
            benefitCard(
                emoji: "📋",
                title: "過去7日間の完了・スキップの記録をまとめて確認",
                accent: .owlAmber
            )
            benefitCard(
                emoji: "🕐",
                title: "「いつ確認したか」が分単位でわかる Last Seen 詳細",
                accent: .blue
            )
        }
    }

    private func benefitCard(emoji: String, title: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(emoji)
                .font(.title2)

            Text(title)
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        }
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
