import SwiftUI

/// 家族モードの設定タブ
struct FamilySettingsTab: View {
    @Environment(AppState.self) private var appState
    @AppStorage("family_paired_person_name") private var pairedPersonName = "お母さん"
    @AppStorage("family_notify_completion") private var notifyCompletion = true
    @AppStorage("family_notify_inactivity") private var notifyInactivity = true

    @State private var isUnlinking = false
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                profileCard
                notificationCard
                pairingCard
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .background(familyScreenBackground)
        .alert("お知らせ", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var activeLinkId: String? {
        appState.familyChildLinkIds.first
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("見守る相手", systemImage: "person.text.rectangle")
                .font(.headline)

            TextField("例: お母さん", text: $pairedPersonName)
                .padding(.horizontal, Spacing.md)
                .frame(height: ComponentSize.inputField)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: CornerRadius.input))

            Text("ホーム上の呼び名として使われます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(familyCardBackground)
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("通知設定", systemImage: "bell.badge.fill")
                .font(.headline)

            toggleRow(
                title: "完了したら知らせる",
                detail: "相手が予定を終えたことを確認しやすくします。",
                isOn: $notifyCompletion
            )

            toggleRow(
                title: "未対応を知らせる",
                detail: "予定の反応がないときに見逃しにくくします。",
                isOn: $notifyInactivity
            )
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(familyCardBackground)
    }

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("ペアリング管理", systemImage: "link")
                .font(.headline)

            Button {
                appState.appMode = .person
            } label: {
                Label("自分で使うモードに切り替える", systemImage: "person.fill.turn.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .secondary))
            .frame(minHeight: 60)

            if let activeLinkId {
                Text("連携中のリンクID: \(activeLinkId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Button(role: .destructive) {
                    unlink(linkId: activeLinkId)
                } label: {
                    if isUnlinking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("ペアリングを解除する", systemImage: "xmark.circle.fill")
                    }
                }
                .buttonStyle(.large(background: .statusDanger))
                .disabled(isUnlinking)
            } else {
                Text("まだペアリングされていません。6桁コードを入力するとここで管理できます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(familyCardBackground)
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.body.weight(.medium))
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func unlink(linkId: String) {
        isUnlinking = true
        Task {
            defer { isUnlinking = false }
            do {
                try await FamilyRemoteService.shared.unlinkFamily(linkId: linkId)
                appState.familyChildLinkIds.removeAll { $0 == linkId }
                alertMessage = "ペアリングを解除しました。"
            } catch {
                alertMessage = "解除に失敗しました。時間をおいてもう一度お試しください。"
            }
        }
    }

    private var familyScreenBackground: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    private var familyCardBackground: some View {
        RoundedRectangle(cornerRadius: CornerRadius.lg)
            .fill(.background)
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }
}
