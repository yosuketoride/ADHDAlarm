import SwiftUI

/// 当事者モードのホーム画面（Phase 2で本実装）
struct PersonHomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack(path: Bindable(appState).personNavigationPath) {
            VStack(spacing: Spacing.lg) {
                Spacer()
                Image("OwlIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                Text("ただいま準備中です")
                    .font(.title2.bold())
                Text("Phase 2で実装されます")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("ホーム")
        }
    }
}
