import SwiftUI

/// 家族モードのホーム画面
/// ペアリング未完了 → FamilyPairingView を全面表示
/// ペアリング済み   → 3タブ（見守り / 送る / 設定）
struct FamilyHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FamilyHomeViewModel()
    @State private var showFamilyPaywall = false
    @AppStorage("family_paired_person_name") private var pairedPersonName = "お母さん"

    /// ペアリング済みか（linkIdが1件以上あるかで判定）
    private var activeLinkId: String? {
        appState.familyChildLinkIds.first
    }

    var body: some View {
        Group {
            if let linkId = activeLinkId {
                pairedView(linkId: linkId)
            } else {
                FamilyPairingView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activeLinkId != nil)
    }

    // MARK: - ペアリング済み: 3タブ

    @ViewBuilder
    private func pairedView(linkId: String) -> some View {
        TabView(selection: $viewModel.selectedTab) {
            // Tab 0: 見守りダッシュボード
            NavigationStack {
                FamilyDashboardTab(
                    pairedPersonName: pairedPersonName,
                    lastSeen: viewModel.lastSeen,
                    events: viewModel.sentEvents,
                    sosMessage: viewModel.sosMessage,
                    isPro: appState.subscriptionTier == .pro,
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
        .task {
            viewModel.bindAppStateIfNeeded(appState)
            await viewModel.loadEvents(linkId: linkId)
        }
        .sheet(isPresented: $showFamilyPaywall) {
            FamilyPaywallView()
        }
    }
}
