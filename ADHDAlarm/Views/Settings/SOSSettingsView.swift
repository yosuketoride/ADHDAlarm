import SwiftUI

/// 家族への自動連絡 設定ページ
///
/// 「家族のLINEを登録する（SOS LINE連携）」と
/// 「アラームへの応答がなければ何分後に連絡するか」の2つをまとめた画面。
struct SOSSettingsView: View {
    @State var settingsViewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    @State private var pairingViewModel: SOSPairingViewModel?

    var body: some View {
        List {
            // ── LINE連携 ──
            Section {
                if let pairingVM = pairingViewModel {
                    SOSPairingView(viewModel: pairingVM)
                        .padding(.vertical, 4)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            } header: {
                Text("お知らせを受け取る家族を登録する")
            } footer: {
                Text("ご家族のLINEに登録すると、アラームへの応答がない場合に自動でメッセージが届きます。")
            }

            // ── 連絡するまでの時間 ──
            Section {
                Picker("反応がなければ何分後に連絡する？", selection: Binding(
                    get: { settingsViewModel.sosEscalationMinutes },
                    set: { settingsViewModel.sosEscalationMinutes = $0 }
                )) {
                    #if DEBUG
                    Text("10秒（テスト用）").tag(0)
                    #endif
                    ForEach([1, 3, 5, 10, 15, 20], id: \.self) { min in
                        Text("\(min)分").tag(min)
                    }
                }
            } header: {
                Text("連絡するまでの時間")
            } footer: {
                let minutes = settingsViewModel.sosEscalationMinutes
                Text("アラームが\(minutes == 0 ? "10秒（テスト）" : "\(minutes)分")間止められなかった場合、登録した家族にお知らせが届きます。")
            }
        }
        .navigationTitle("家族への自動連絡")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if pairingViewModel == nil {
                pairingViewModel = SOSPairingViewModel(appState: appState)
            }
        }
    }
}
