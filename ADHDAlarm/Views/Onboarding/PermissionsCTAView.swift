import SwiftUI

/// オンボーディング Step 3: 権限リクエスト（CTA）
/// テスト体験でテンションが上がった直後に一気に権限を取得する
struct PermissionsCTAView: View {
    @Environment(PermissionsService.self) private var permissions
    @Environment(\.scenePhase) private var scenePhase
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 見出し
                VStack(spacing: 12) {
                    Image("OwlIcon")
                        .resizable().scaledToFit()
                        .frame(width: 60, height: 60)

                    Text("Siriとマイクを\n許可して始めましょう")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("以下の「許可」をタップするだけで\n設定は完了です。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Siri呼び方ヒント
                HStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("「Hey Siri、こえメモにお願い」")
                            .font(.callout.weight(.semibold))
                        Text("このフレーズでSiriが予定の登録を手伝います")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                // 権限ステータス一覧
                VStack(spacing: 12) {
                    permissionRow(
                        icon: "calendar",
                        title: "カレンダーへのアクセス",
                        description: "予定を読み込んでアラームと連動させます",
                        isGranted: permissions.isCalendarAuthorized
                    )
                    permissionRow(
                        icon: "alarm.fill",
                        title: "アラームの設定",
                        description: "マナーモードを貫通するアラームをセットします",
                        isGranted: permissions.isAlarmKitAuthorized
                    )
                    permissionRow(
                        icon: "mic.fill",
                        title: "マイクと音声認識",
                        description: "声で予定を入力するために使います",
                        isGranted: permissions.isSpeechAuthorized && permissions.isMicrophoneAuthorized
                    )
                }
                .padding(.horizontal, 20)

                // ボタンエリア
                if !permissions.isAllAuthorized {
                    VStack(spacing: 12) {
                        if permissions.hasDeniedPermissions {
                            // 拒否済み権限がある → 設定アプリへ誘導
                            VStack(spacing: 8) {
                                Text("一部の機能がオフになっています。\niPhoneの「設定」アプリから許可してくださいね。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)

                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("設定アプリで許可する", systemImage: "gear")
                                }
                                .buttonStyle(.large(background: .orange))
                            }
                        } else {
                            // 未リクエスト → 通常の一括許可ボタン
                            Button {
                                isRequesting = true
                                Task {
                                    await permissions.requestAll()
                                    isRequesting = false
                                }
                            } label: {
                                if isRequesting {
                                    HStack(spacing: 12) {
                                        ProgressView().tint(.white)
                                        Text("確認中…")
                                    }
                                } else {
                                    Label("Siriとマイクを許可して始める", systemImage: "checkmark.shield.fill")
                                }
                            }
                            .buttonStyle(.large(background: .blue))
                            .disabled(isRequesting)
                        }
                    }
                    .padding(.horizontal, 24)
                } else {
                    // 全許可済み
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("すべての準備が整いました！")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 16)
                }

                Spacer(minLength: 16)
            }
        }
        .contentMargins(.bottom, 160, for: .scrollContent)
        // 設定アプリから戻ったとき権限状態を更新する
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                permissions.refreshStatuses()
            }
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        isGranted: Bool
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isGranted ? .green : .secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
