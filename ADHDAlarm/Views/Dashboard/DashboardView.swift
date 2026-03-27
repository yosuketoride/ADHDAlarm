import SwiftUI

/// メイン画面「見るだけダッシュボード」
/// 開いた瞬間に予定が全てわかり、マイクFABで新規追加できる
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @Environment(AppState.self)  private var appState
    @Environment(AppRouter.self) private var router
    @State private var showMicInput = false
    @State private var showSettings = false

    init() {
        _viewModel = State(initialValue: DashboardViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // コンシェルジュの挨拶
                    greetingSection

                    // ウィジェット状態バナー
                    WidgetStatusBanner(isInstalled: viewModel.isWidgetInstalled)
                        .padding(.horizontal, 16)

                    // 次のアラームカウントダウン
                    if let next = viewModel.nextAlarm {
                        NextAlarmCard(alarm: next)
                            .padding(.horizontal, 16)
                    }

                    // 今日の予定リスト
                    eventListSection
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("ふくろう")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                // デバッグビルドのみ表示: オンボーディングをリセットして最初の画面に戻る
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.isOnboardingComplete = false
                        router.currentDestination = .onboarding
                    } label: {
                        Label("最初から", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                #endif
            }
            // 設定画面
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    viewModel: SettingsViewModel(appState: appState)
                )
            }
            // マイク入力をシート表示
            .sheet(isPresented: $showMicInput) {
                MicrophoneInputView(viewModel: InputViewModel(appState: appState))
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .onDisappear {
                        // シートを閉じたら予定リストを更新
                        Task { await viewModel.loadEvents() }
                    }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // 巨大マイクFABボタン（常に右下に固定）
            micFAB
        }
        .task {
            await viewModel.loadEvents()
            await viewModel.checkWidgetStatus()
        }
    }

    // MARK: - サブビュー

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.greeting)
                .font(.title2.weight(.bold))
            Text(viewModel.eventSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.events.isEmpty {
                emptyStateView
            } else {
                Text("今日のご予定")
                    .font(.headline)
                    .padding(.horizontal, 20)

                ForEach(viewModel.events) { alarm in
                    EventRow(alarm: alarm) {
                        Task { await viewModel.deleteEvent(alarm) }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("ご予定はまだありません")
                .font(.title3.weight(.medium))

            ConciergeText(message: "右下のマイクボタンを押して\n予定を追加してみましょう。")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var micFAB: some View {
        Button {
            showMicInput = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 72, height: 72)
                    .shadow(color: .blue.opacity(0.4), radius: 12, y: 4)

                Image(systemName: "mic.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 24)
        .padding(.bottom, 32)
    }
}
