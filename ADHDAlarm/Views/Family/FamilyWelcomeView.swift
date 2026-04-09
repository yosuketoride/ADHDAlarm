import SwiftUI

/// 家族モードの初回オンボーディング画面
/// 機能紹介 → 無料ペアリング or PRO購入 の導線を提供する
/// 2回目以降（family_welcome_shown == true）はスキップされ、FamilyPairingView が直接表示される
struct FamilyWelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false

    /// 「ペアリングへ進む」を呼んだときのコールバック（FamilyHomeView 側でフラグを立てる）
    var onProceed: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                heroSection
                featureSection
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
        .sheet(isPresented: $showPaywall, onDismiss: {
            // 購入の有無に関わらずペアリング画面へ進む
            onProceed()
        }) {
            FamilyPaywallView()
        }
    }

    // MARK: - ヒーロー

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            Image("owl_stage0_normal")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)

            Text("離れていても、そばにいられる")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("予定を送ったり、様子を確認したり。\n家族として本人をさりげなく支えられます。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [Color.owlAmber.opacity(0.18), Color.blue.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.lg)
        )
    }

    // MARK: - 機能紹介

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            featureRow(
                emoji: "📨",
                title: "予定をワンタップで送れる",
                detail: "お薬・病院・ご飯など。相手のスマホにアラームとして届きます。",
                isFree: false
            )
            featureRow(
                emoji: "🆘",
                title: "アラームが止まらないとき自動でお知らせ",
                detail: "5分間反応がないと、あなたのスマホに通知が届きます。",
                isFree: false
            )
            featureRow(
                emoji: "📋",
                title: "過去7日間の記録をまとめて確認",
                detail: "完了・スキップの履歴をいつでも振り返れます。",
                isFree: false
            )
        }
    }

    private func featureRow(emoji: String, title: String, detail: String, isFree: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(emoji)
                .font(.title2)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    if !isFree {
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.owlAmber, in: Capsule())
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                showPaywall = true
            } label: {
                Text("PRO機能も使いたい（月額880円）")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .background(Color.owlAmber, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            }
            .buttonStyle(.plain)

            Button {
                onProceed()
            } label: {
                Text("無料でペアリングだけする")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
            }
            .buttonStyle(.plain)

            Button {
                // appMode を nil にして ModeSelectionView に戻す
                // （家族モード選択時に isOnboardingComplete = true になるため、
                //   .person を直接セットすると本人オンボーディングがスキップされてしまう）
                appState.appMode = nil
            } label: {
                Text("やっぱり自分で使う")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .background(.ultraThinMaterial)
    }
}
