import SwiftUI

/// Tab 3: 設定タブ
struct SettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        SettingsView(
            viewModel: SettingsViewModel(appState: appState)
        )
    }
}
