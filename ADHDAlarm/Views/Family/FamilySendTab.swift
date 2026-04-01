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
                    summaryCard
                    sendButton
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .background(Color(.systemGroupedBackground))
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
        .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
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
        .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
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
                                : Color(.secondarySystemBackground),
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
            Text("いつ届ける？")
                .font(.headline)

            ForEach(FamilySendTimingOption.allCases) { option in
                Button {
                    viewModel.selectedTiming = option
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: viewModel.selectedTiming == option ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(viewModel.selectedTiming == option ? Color.owlAmber : .secondary)
                        Text(option.label)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: ComponentSize.settingRow)
                    .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .buttonStyle(.plain)
            }

            if viewModel.selectedTiming == .custom {
                DatePicker(
                    "日時",
                    selection: $viewModel.customDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(Spacing.sm)
                .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("送信内容")
                .font(.headline)
            Text(viewModel.resolvedTitle.isEmpty ? "内容を入力してください" : viewModel.resolvedTitle)
                .font(.title3.weight(.bold))
            Text("予定時刻: \(viewModel.scheduledDate.naturalJapaneseString)")
                .font(.callout)
            Text("通知タイミング: \(appState.preNotificationMinutes == 0 ? "時間ちょうど" : "\(appState.preNotificationMinutes)分前")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
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
                Text("通知は\(appState.preNotificationMinutes == 0 ? "時間ちょうど" : "\(appState.preNotificationMinutes)分前")に設定されます。")
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
                    preNotificationMinutes: appState.preNotificationMinutes,
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
    var selectedTiming: FamilySendTimingOption = .in15Minutes
    var customDate: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    var sendState: SendState = .idle

    private let service: FamilyScheduling

    init(service: FamilyScheduling? = nil) {
        self.service = service ?? FamilyRemoteService.shared
    }

    var scheduledDate: Date {
        switch selectedTiming {
        case .now:
            return Date()
        case .in15Minutes:
            return Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        case .in30Minutes:
            return Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        case .in1Hour:
            return Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
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

private enum FamilySendTimingOption: CaseIterable, Identifiable {
    case now
    case in15Minutes
    case in30Minutes
    case in1Hour
    case custom

    var id: String { label }

    var label: String {
        switch self {
        case .now: return "今から"
        case .in15Minutes: return "15分後"
        case .in30Minutes: return "30分後"
        case .in1Hour: return "1時間後"
        case .custom: return "カスタム"
        }
    }
}
