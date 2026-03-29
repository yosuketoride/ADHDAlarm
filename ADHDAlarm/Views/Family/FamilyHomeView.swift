import SwiftUI

/// 家族モードのホーム画面（Phase 4で本実装）
struct FamilyHomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack(path: Bindable(appState).familyNavigationPath) {
            VStack(spacing: Spacing.lg) {
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.system(size: IconSize.xl))
                    .foregroundStyle(Color.owlBrown)
                Text("ただいま準備中です")
                    .font(.title2.bold())
                Text("Phase 4で実装されます")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("家族ホーム")
        }
    }
}
