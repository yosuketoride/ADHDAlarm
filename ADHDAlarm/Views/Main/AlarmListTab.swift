import SwiftUI

/// Tab 2: 予定リストタブ（Apple 時計アプリ風）
struct AlarmListTab: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(AppState.self)  private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            List {
                // 次のアラームカウントダウンカード
                if let next = viewModel.nextAlarm {
                    Section {
                        NextAlarmCard(alarm: next)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                // ウィジェット状態バナー（未設置時のみ表示）
                if !viewModel.isWidgetInstalled {
                    Section {
                        WidgetStatusBanner(isInstalled: viewModel.isWidgetInstalled)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                // 今日の予定リスト
                Section {
                    if viewModel.events.isEmpty {
                        emptyStateRow
                    } else {
                        ForEach(viewModel.events) { alarm in
                            EventRow(alarm: alarm) {
                                Task { await viewModel.deleteEvent(alarm) }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                } header: {
                    HStack {
                        Text("今日のご予定")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(viewModel.eventSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("声メモアラーム")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
            .refreshable {
                await viewModel.loadEvents()
            }
        }
        // 削除Undoトースト
        .safeAreaInset(edge: .bottom) {
            if let pending = viewModel.pendingDelete {
                undoToast(title: pending.title)
            }
        }
        .task {
            await viewModel.loadEvents()
        }
    }

    // MARK: - 削除Undoトースト

    private func undoToast(title: String) -> some View {
        HStack {
            Text("「\(title)」をとりけしました")
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Button("元に戻す") {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.undoDelete()
                }
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 空の状態

    private var emptyStateRow: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("ご予定はまだありません")
                .font(.title3.weight(.medium))
            Text("「追加」タブのマイクボタンで\n予定を追加してみましょう。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
