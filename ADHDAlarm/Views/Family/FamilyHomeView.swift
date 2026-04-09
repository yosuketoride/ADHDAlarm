import SwiftUI

/// 家族モードのホーム画面
/// ペアリング未完了・初回 → FamilyPaywallView
/// ペアリング未完了・2回目以降 → FamilyPairingView を直接表示
/// ペアリング済み   → 3タブ（見守り / 送る / 設定）
struct FamilyHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(NetworkMonitorService.self) private var networkMonitor
    @State private var viewModel = FamilyHomeViewModel()
    @State private var showFamilyPaywall = false
    @AppStorage("family_paired_person_name") private var pairedPersonName = "お母さん"
    /// 初回のみ WelcomeView を表示するフラグ。ペアリング解除時にリセットされる
    @AppStorage("family_welcome_shown") private var familyWelcomeShown = false

    /// ペアリング済みか（linkIdが1件以上あるかで判定）
    private var activeLinkId: String? {
        appState.familyChildLinkIds.first
    }

    var body: some View {
        Group {
            if let linkId = activeLinkId {
                pairedView(linkId: linkId)
            } else if familyWelcomeShown {
                FamilyPairingView()
            } else {
                FamilyPaywallView(onContinueWithoutUpgrade: {
                    familyWelcomeShown = true
                })
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activeLinkId != nil)
    }

    // MARK: - ペアリング済み: 3タブ

    @ViewBuilder
    private func pairedView(linkId: String) -> some View {
        TabView(selection: $viewModel.selectedTab) {
            // Tab 0: 見守りダッシュボード（タブを開くたびに自動リフレッシュ）
            NavigationStack {
                FamilyDashboardTab(
                    pairedPersonName: pairedPersonName,
                    lastSeen: viewModel.lastSeen,
                    events: viewModel.sentEvents,
                    sosMessage: viewModel.sosMessage,
                    isPro: appState.subscriptionTier == .pro,
                    showFirstCompletionBanner: viewModel.shouldShowFirstCompletionBanner,
                    onDismissFirstCompletionBanner: { viewModel.dismissFirstCompletionBanner() },
                    onUpgradeTapped: { showFamilyPaywall = true }
                )
                .navigationTitle("\(pairedPersonName)さんの様子")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task { await viewModel.refresh(linkId: linkId) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: IconSize.sm))
                                .frame(width: 60, height: 60)
                        }
                        .disabled(viewModel.isLoadingEvents)
                    }
                }
                .refreshable { await viewModel.refresh(linkId: linkId) }
            }
            .tabItem { Label("見守り", systemImage: "eye.fill") }
            .tag(0)
            .onChange(of: viewModel.selectedTab) { _, newTab in
                if newTab == 0 {
                    Task { await viewModel.refresh(linkId: linkId) }
                }
            }

            // Tab 1: 予定を送る
            NavigationStack {
                FamilySendTab()
                    .navigationTitle("予定を送る")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("送る", systemImage: "paperplane.fill") }
            .tag(1)

            // Tab 2: 設定
            NavigationStack {
                FamilySettingsTab()
                    .navigationTitle("設定")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("設定", systemImage: "gearshape.fill") }
            .tag(2)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if networkMonitor.isOffline {
                    offlineBanner
                }
                if let errorMessage = viewModel.fetchError {
                    fetchErrorBanner(message: errorMessage)
                }
            }
        }
        .task {
            viewModel.bindAppStateIfNeeded(appState)
            await viewModel.loadEvents(linkId: linkId)
        }
        .sheet(isPresented: $showFamilyPaywall) {
            FamilyPaywallView()
        }
    }

    private func fetchErrorBanner(message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
            Text(message)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.black.opacity(0.82))
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.85))
    }

    private var offlineBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.callout.weight(.semibold))
            Text("インターネットにつながっていません。最新の予定や見守り状況の読み込みが遅れることがあります。")
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.black.opacity(0.82))
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.88))
    }
}
