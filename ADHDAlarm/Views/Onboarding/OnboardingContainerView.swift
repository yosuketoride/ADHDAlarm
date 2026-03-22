import SwiftUI

/// オンボーディングコンテナ（4ステップ）
/// Hook → Magic Demo → Permissions CTA → Widget Guide
struct OnboardingContainerView: View {
    @Environment(AppState.self)  private var appState
    @Environment(AppRouter.self) private var router
    @Environment(PermissionsService.self) private var permissions
    @State private var currentPage = 0

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

            // ナビゲーションフッター（ページインジケータ＋ボタン）
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

                // 次へ / 完了ボタン
                Button {
                    advancePage()
                } label: {
                    Text(nextButtonLabel)
                }
                .buttonStyle(.large(background: nextButtonColor))
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 16)
            .padding(.bottom, 34)
            .background(.ultraThinMaterial)
        }
    }

    private var nextButtonLabel: String {
        switch currentPage {
        case 0: return "体験してみる →"
        case 1: return "連携設定へ →"
        case 2: return permissions.isAllAuthorized ? "ウィジェットを設置する →" : "あとで設定する"
        case 3: return "はじめる！"
        default: return "次へ →"
        }
    }

    private var nextButtonColor: Color {
        currentPage == totalPages - 1 ? .green : .blue
    }

    private func advancePage() {
        if currentPage < totalPages - 1 {
            withAnimation { currentPage += 1 }
        } else {
            // オンボーディング完了
            appState.isOnboardingComplete = true
            router.completeOnboarding()
        }
    }
}
