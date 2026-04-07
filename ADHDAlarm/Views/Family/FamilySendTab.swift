import Observation
import SwiftUI

/// 家族がワンタップで予定を送るための送信タブ
struct FamilySendTab: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FamilySendTabViewModel()
    @State private var showConfirmation = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                introCard

                if !isPro {
                    proRequiredCard
                } else if activeLinkId == nil {
                    pairingRequiredCard
                } else {
                    templateSection
                    customTitleSection
                    timingSection
                    notificationTimingSection
                    summaryCard
                    sendButton
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .background(familyScreenBackground)
        .sheet(isPresented: $showConfirmation) {
            confirmationSheet
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var activeLinkId: String? {
        appState.familyChildLinkIds.first
    }

    private var isPro: Bool {
        appState.subscriptionTier == .pro
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("ワンタップで予定を送れます")
                .font(.title3.weight(.bold))
            Text("よく使う内容を選ぶか自由に入力して、時間を決めるだけです。相手のiPhoneには通常のアラーム予定として届きます。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(familyCardBackground)
    }

    private var pairingRequiredCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("まずはペアリングを完了してください", systemImage: "link.badge.plus")
                .font(.headline)
                .foregroundStyle(Color.owlAmber)
            Text("6桁コードの入力が済むと、ここから予定を送れるようになります。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.owlAmber.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private var proRequiredCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("家族リモートアラームはPRO機能です", systemImage: "star.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("ご家族へ予定を送る機能は、PROプランで使えます。アップグレードするとテンプレート送信や見守り機能が解放されます。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                showPaywall = true
            } label: {
                Label("PROプランを見る", systemImage: "star.fill")
            }
            .buttonStyle(.large(background: .blue))
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(familyCardBackground)
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("テンプレート")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(FamilyQuickTemplate.allCases) { template in
                        Button {
                            viewModel.selectTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(template.emoji)
                                    .font(.system(size: IconSize.lg))
                                Text(template.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(viewModel.selectedTemplate == template ? .black : .primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .padding(Spacing.md)
                            .frame(width: 156, height: 112, alignment: .topLeading)
                            .background(
                                viewModel.selectedTemplate == template
                                ? Color.owlAmber
                                : Color(.systemBackground),
                                in: RoundedRectangle(cornerRadius: CornerRadius.lg)
                            )
                        }
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }
    }

    private var customTitleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("内容を自由に入力")
                .font(.headline)
            TextField("例：買い物、お薬、電話、ゴミ出し", text: $viewModel.customTitle)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .onChange(of: viewModel.customTitle) { _, newValue in
                    viewModel.customTitle = String(newValue.prefix(30))
                }
            Text("30文字まで入力できます。テンプレートを選ばなくても送れます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("いつの予定？")
                .font(.headline)

            // 朝・昼・夜 + 相対時間 + 細かく設定（本人側UIに準拠）
            timeGrid

            if viewModel.selectedTiming == .custom {
                DatePicker(
                    "日時",
                    selection: $viewModel.customDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(Spacing.sm)
                .background(familyCardBackground)
            }
        }
    }

    private var timeGrid: some View {
        VStack(spacing: 12) {
            // 絶対時刻プリセット（朝・昼・夜）
            HStack(spacing: 12) {
                timingButton(.morning)
                timingButton(.noon)
                timingButton(.evening)
            }
            // 相対時間プリセット
            HStack(spacing: 12) {
                timingButton(.relative(10))
                timingButton(.relative(30))
                timingButton(.relative(60))
            }
            // 細かく設定（DatePicker開閉）
            Button {
                viewModel.selectedTiming = viewModel.selectedTiming == .custom ? .morning : .custom
            } label: {
                Text(viewModel.selectedTiming == .custom ? "閉じる" : "⚙️ 細かく設定")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(viewModel.selectedTiming == .custom ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(
                        viewModel.selectedTiming == .custom ? Color.owlAmber : Color(.tertiarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func timingButton(_ option: FamilySendTimingOption) -> some View {
        let isSelected = viewModel.selectedTiming == option
        return Button {
            viewModel.selectedTiming = option
        } label: {
            VStack(spacing: 4) {
                Text(option.emoji)
                    .font(.title3)
                Text(option.label)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if !option.timeDescription.isEmpty {
                    Text(option.timeDescription)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72)
            .background(isSelected ? Color.owlAmber : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("送信内容")
                .font(.headline)
            Text(viewModel.resolvedTitle.isEmpty ? "内容を入力してください" : viewModel.resolvedTitle)
                .font(.title3.weight(.bold))
            Text("予定時刻: \(viewModel.scheduledDate.naturalJapaneseString)")
                .font(.callout)
            Text("通知タイミング: \(viewModel.preNotificationMinutes == 0 ? "時間ちょうど" : "\(viewModel.preNotificationMinutes)分前")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(familyCardBackground)
    }

    private var notificationTimingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("予定の何分前に知らせる？")
                .font(.headline)

            // 本人側UIに合わせて 0/1/5/10/15/30/60 分の7択をチップで選ぶ
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach([0, 1, 5, 10, 15, 30, 60], id: \.self) { minutes in
                        Button {
                            viewModel.preNotificationMinutes = minutes
                        } label: {
                            Text(minutes == 0 ? "時間ちょうど" : "\(minutes)分前")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(viewModel.preNotificationMinutes == minutes ? .white : .primary)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(
                                    viewModel.preNotificationMinutes == minutes
                                        ? Color.owlAmber
                                        : Color(.systemBackground),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }
    }

    @ViewBuilder
    private var sendButton: some View {
        switch viewModel.sendState {
        case .idle:
            Button {
                showConfirmation = true
            } label: {
                Label("この予定を送る", systemImage: "paperplane.fill")
            }
            .buttonStyle(.large(background: .blue))
            .disabled(!viewModel.canSend)

        case .sending:
            ProgressView("送信中です…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)

        case .sent:
            Label("送りました", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.statusSuccess)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .onAppear {
                    // 2秒後にフォームをリセットして次の送信を可能にする
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        viewModel.reset()
                    }
                }

        case .error(let message):
            VStack(spacing: Spacing.sm) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.statusDanger)
                    .font(.callout)
                Button("もう一度試す") {
                    viewModel.sendState = .idle
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var confirmationSheet: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
                .padding(.top, Spacing.lg)

            Text("この内容で送りますか？")
                .font(.headline)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(viewModel.resolvedTitle)
                    .font(.title3.weight(.bold))
                Text(viewModel.scheduledDate.naturalJapaneseString)
                    .font(.body)
                Text("通知は\(viewModel.preNotificationMinutes == 0 ? "時間ちょうど" : "\(viewModel.preNotificationMinutes)分前")に設定されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .padding(.horizontal, Spacing.md)

            Button {
                showConfirmation = false
                guard let activeLinkId else { return }
                viewModel.send(
                    familyLinkId: activeLinkId,
                    preNotificationMinutes: viewModel.preNotificationMinutes,
                    voiceCharacter: appState.voiceCharacter
                )
            } label: {
                Label("送る", systemImage: "paperplane.fill")
            }
            .buttonStyle(.large(background: .blue))
            .padding(.horizontal, Spacing.md)

            Button("修正する") {
                showConfirmation = false
            }
            .buttonStyle(.bordered)
            .padding(.bottom, Spacing.lg)
        }
        .presentationDetents([.medium])
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

@Observable
@MainActor
private final class FamilySendTabViewModel {
    enum SendState: Equatable {
        case idle
        case sending
        case sent
        case error(String)
    }

    var selectedTemplate: FamilyQuickTemplate? = .medicine
    var customTitle: String = ""
    var selectedTiming: FamilySendTimingOption = .morning  // デフォルトは次の朝
    var preNotificationMinutes: Int = 15
    var customDate: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    var sendState: SendState = .idle

    private let service: FamilyScheduling

    init(service: FamilyScheduling? = nil) {
        self.service = service ?? FamilyRemoteService.shared
    }

    var scheduledDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch selectedTiming {
        case .morning:
            // 今日の8時がすでに過ぎていたら明日の朝に
            var comp = cal.dateComponents([.year, .month, .day], from: now)
            comp.hour = 8; comp.minute = 0
            let today8 = cal.date(from: comp)!
            return today8 > now ? today8 : cal.date(byAdding: .day, value: 1, to: today8)!
        case .noon:
            var comp = cal.dateComponents([.year, .month, .day], from: now)
            comp.hour = 12; comp.minute = 0
            let today12 = cal.date(from: comp)!
            return today12 > now ? today12 : cal.date(byAdding: .day, value: 1, to: today12)!
        case .evening:
            var comp = cal.dateComponents([.year, .month, .day], from: now)
            comp.hour = 19; comp.minute = 0
            let today19 = cal.date(from: comp)!
            return today19 > now ? today19 : cal.date(byAdding: .day, value: 1, to: today19)!
        case .relative(let minutes):
            return now.addingTimeInterval(Double(minutes) * 60)
        case .custom:
            return customDate
        }
    }

    var canSend: Bool {
        !resolvedTitle.isEmpty && scheduledDate >= Date()
    }

    var resolvedTitle: String {
        let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return selectedTemplate?.title ?? ""
    }

    /// 送信完了後にフォームを初期状態に戻す
    func reset() {
        selectedTemplate = .medicine
        customTitle = ""
        selectedTiming = .morning
        preNotificationMinutes = 15
        customDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        sendState = .idle
    }

    func selectTemplate(_ template: FamilyQuickTemplate) {
        selectedTemplate = template
        if customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            customTitle = template.title
        }
    }

    func send(familyLinkId: String, preNotificationMinutes: Int, voiceCharacter: VoiceCharacter) {
        guard canSend else { return }
        sendState = .sending

        Task {
            do {
                _ = try await service.ensureDeviceRegistered()
                let payload = RemoteEventPayload(
                    familyLinkId: familyLinkId,
                    title: resolvedTitle,
                    fireDate: scheduledDate,
                    preNotificationMinutes: preNotificationMinutes,
                    voiceCharacter: voiceCharacter.rawValue,
                    note: nil
                )
                try await service.createRemoteEvent(payload)
                sendState = .sent
            } catch {
                sendState = .error("送信できませんでした。通信状況を確認してもう一度お試しください。")
            }
        }
    }
}

private enum FamilyQuickTemplate: CaseIterable, Identifiable {
    case medicine
    case hospital
    case meal
    case nap
    case walk
    case call

    var id: String { title }

    var emoji: String {
        switch self {
        case .medicine: return "💊"
        case .hospital: return "🏥"
        case .meal: return "🍜"
        case .nap: return "🛌"
        case .walk: return "🚶"
        case .call: return "📞"
        }
    }

    var title: String {
        switch self {
        case .medicine: return "お薬の時間"
        case .hospital: return "病院へ行く"
        case .meal: return "ご飯の時間"
        case .nap: return "お昼寝して"
        case .walk: return "散歩の時間"
        case .call: return "電話してね"
        }
    }
}

private enum FamilySendTimingOption: Equatable, Identifiable {
    case morning
    case noon
    case evening
    case relative(Int)  // N分後
    case custom

    var id: String {
        switch self {
        case .morning:         return "morning"
        case .noon:            return "noon"
        case .evening:         return "evening"
        case .relative(let m): return "relative_\(m)"
        case .custom:          return "custom"
        }
    }

    var emoji: String {
        switch self {
        case .morning:         return "☀️"
        case .noon:            return "🕛"
        case .evening:         return "🌙"
        case .relative(let m): return m < 60 ? "⏱" : "⏰"
        case .custom:          return ""
        }
    }

    var label: String {
        switch self {
        case .morning:         return "朝"
        case .noon:            return "昼"
        case .evening:         return "夜"
        case .relative(let m): return m >= 60 ? "1時間後" : "\(m)分後"
        case .custom:          return "細かく設定"
        }
    }

    /// グリッドボタン内のサブテキスト（時刻の目安）
    var timeDescription: String {
        switch self {
        case .morning:         return "8:00"
        case .noon:            return "12:00"
        case .evening:         return "19:00"
        case .relative(let m): return m >= 60 ? "1時間後" : "\(m)分後"
        case .custom:          return ""
        }
    }
}
