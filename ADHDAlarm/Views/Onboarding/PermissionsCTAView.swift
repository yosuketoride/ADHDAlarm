import SwiftUI

/// オンボーディング: 権限プリプロンプト（通知 → カレンダー の2ステップ）
struct PermissionsCTAView: View {
    @Environment(AppState.self) private var appState
    @Environment(PermissionsService.self) private var permissions

    private enum PermissionsStep { case notifications, calendar }
    @State private var step: PermissionsStep = .notifications
    @State private var isRequesting = false

    var body: some View {
        Group {
            if step == .notifications {
                notificationStep
            } else {
                calendarStep
            }
        }
        .navigationBarBackButtonHidden()
        .animation(.easeInOut(duration: 0.3), value: step == .notifications)
    }

    // MARK: - 通知ステップ

    private var notificationStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("owl_stage0_normal")
                .resizable().scaledToFit()
                .frame(width: 120, height: 120)

            Spacer().frame(height: Spacing.xl)

            VStack(spacing: Spacing.sm) {
                Text("マナーモードでも\n必ずお知らせするために\n「通知」を使います")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.md)

            Spacer().frame(height: Spacing.lg)

            Text("📵 通知をオフにすると\nアラームが鳴りません")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            Spacer()

            VStack(spacing: Spacing.md) {
                Button {
                    Task {
                        isRequesting = true
                        await permissions.requestNotification()
                        isRequesting = false
                        withAnimation { step = .calendar }
                    }
                } label: {
                    if isRequesting {
                        ProgressView().tint(.black)
                    } else {
                        Text("通知を許可する")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.primary)
                .background(Color.owlAmber)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .disabled(isRequesting)

                Button("あとで →") {
                    withAnimation { step = .calendar }
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: ComponentSize.small)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - カレンダーステップ

    private var calendarStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: IconSize.xl))
                .foregroundStyle(Color.owlAmber)

            Spacer().frame(height: Spacing.xl)

            Text("いつもの予定を読み込むために\n「カレンダー」を使います")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            Spacer().frame(height: Spacing.lg)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("iPhoneにある予定が自動でアラームになります", systemImage: "checkmark.circle.fill")
                Label("他のカレンダーアプリと同期されます", systemImage: "checkmark.circle.fill")
            }
            .font(.body)
            .foregroundStyle(.primary)
            .symbolRenderingMode(.multicolor)
            .padding(.horizontal, Spacing.md)

            Spacer()

            VStack(spacing: Spacing.md) {
                Button {
                    Task {
                        isRequesting = true
                        await permissions.requestCalendar()
                        isRequesting = false
                        appState.onboardingPath.append(OnboardingDestination.owlNaming)
                    }
                } label: {
                    if isRequesting {
                        ProgressView().tint(.black)
                    } else {
                        Text("カレンダーを連携する")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.primary)
                .background(Color.owlAmber)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .disabled(isRequesting)

                Button("あとで →") {
                    appState.onboardingPath.append(OnboardingDestination.owlNaming)
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: ComponentSize.small)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }
}
