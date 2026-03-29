import SwiftUI

/// オンボーディングコンテナ（4ステップ）
/// Hook → Magic Demo → Permissions CTA → Widget Guide
struct OnboardingContainerView: View {
    @Environment(AppState.self)  private var appState
    @Environment(AppRouter.self) private var router
    @State private var currentPage = 0
    /// オンボーディング完了直後に1回だけ表示するPaywall
    @State private var showOnboardingPaywall = false

    private let totalPages = 4

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                HookView()
                    .tag(0)
                MagicDemoView()
                    .tag(1)
                PermissionsCTAView()
                    .tag(2)
                WidgetGuideView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // ナビゲーションフッター（ページインジケータ＋最終ページのみボタン）
            VStack(spacing: 20) {
                // ページインジケータ
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { page in
                        Capsule()
                            .fill(page == currentPage ? Color.blue : Color(.systemGray4))
                            .frame(width: page == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }

                // 最終ページのみ「はじめる！」ボタンを表示（それまではスワイプで進む）
                if currentPage == totalPages - 1 {
                    Button {
                        advancePage()
                    } label: {
                        Text("はじめる！")
                    }
                    .buttonStyle(.large(background: .green))
                    .padding(.horizontal, 32)
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 34)
            // 最終ページのみ背景マテリアルを表示（それ以前はドットだけ浮かせる）
            .background(currentPage == totalPages - 1 ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
        }
        // オンボーディング完了後のPaywall（1回だけ・全画面）
        .fullScreenCover(isPresented: $showOnboardingPaywall, onDismiss: {
            // TODO: Phase 2で削除
        }) {
            PaywallView(
                viewModel: PaywallViewModel(
                    storeKit: StoreKitService(),
                    appState: appState
                )
            )
        }
    }

    private func advancePage() {
        if currentPage < totalPages - 1 {
            withAnimation { currentPage += 1 }
        } else {
            // オンボーディング完了: isOnboardingCompleteを先にセット（アプリをキルされても再表示しない）
            appState.isOnboardingComplete = true
            if appState.subscriptionTier == .pro {
                // すでにPRO（他デバイスで購入済み等）はPaywallをスキップ
                // TODO: Phase 2で削除
            } else {
                showOnboardingPaywall = true
            }
        }
    }
}
