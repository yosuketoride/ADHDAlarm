import SwiftUI

/// 子側の予定入力画面（GUIテンプレートベース）
/// 電車・職場など声を出せない環境での操作を前提に、タップのみで完結する設計
struct FamilyInputView: View {
    @State var viewModel: FamilyInputViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: テンプレートボタン群
                    templateSection

                    // MARK: タイトル入力
                    titleSection

                    // MARK: 日時
                    dateSection

                    // MARK: 事前通知
                    notificationSection

                    // MARK: 音声キャラクター
                    characterSection

                    // MARK: 送信ボタン
                    sendButton
                }
                .padding()
            }
            .navigationTitle("予定を送る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showConfirmation) {
                confirmationSheet
            }
            .onChange(of: viewModel.sendState) { _, state in
                if case .sent = state {
                    // レビュー指摘: DispatchQueue.main.asyncAfter はキャンセル不可で
                    // dismiss後にも呼ばれ画面スタックが崩れる恐れがある。Task に変更。
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !Task.isCancelled else { return }
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - テンプレートセクション

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("よく使う予定")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(EventTemplate.allCases, id: \.self) { template in
                    templateButton(template)
                }
            }
        }
    }

    private func templateButton(_ template: EventTemplate) -> some View {
        let isSelected = viewModel.selectedTemplate == template
        return Button {
            if isSelected {
                viewModel.clearTemplate()
            } else {
                viewModel.selectTemplate(template)
            }
        } label: {
            HStack(spacing: 8) {
                Text(template.icon)
                    .font(.title3)
                Text(template.defaultTitle ?? template.rawValue)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - タイトル入力

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("内容")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("例：お薬を飲む、ゴミを出す…", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)
                .font(.body)
        }
    }

    // MARK: - 日時

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("日時")
                .font(.caption)
                .foregroundStyle(.secondary)
            DatePicker(
                "日時",
                selection: $viewModel.fireDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
    }

    // MARK: - 事前通知タイミング

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("アラームを鳴らすタイミング")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("事前通知", selection: $viewModel.preNotificationMinutes) {
                Text("時間ちょうど").tag(0)
                Text("5分前").tag(5)
                Text("15分前").tag(15)
                Text("30分前").tag(30)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 音声キャラクター

    private var characterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("声の種類")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("声の種類", selection: $viewModel.voiceCharacter) {
                ForEach(VoiceCharacter.allCases, id: \.self) { char in
                    Text(char.displayName).tag(char)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - 送信ボタン

    @ViewBuilder
    private var sendButton: some View {
        switch viewModel.sendState {
        case .idle:
            Button {
                showConfirmation = true
            } label: {
                Label("この予定を送る", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.large(background: .blue))
            .disabled(!viewModel.isReadyToSend)

        case .sending:
            ProgressView("送信中…")
                .frame(maxWidth: .infinity)
                .padding()

        case .sent:
            Label("送りました！", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()

        case .error(let message):
            VStack(spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                Button("もう一度試す") {
                    viewModel.sendState = .idle
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - 確認シート（思いやりプレビュー）

    private var confirmationSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundStyle(.pink)
                .padding(.top, 24)

            Text("予定の確認")
                .font(.headline)

            Text(viewModel.previewText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 10) {
                Button {
                    showConfirmation = false
                    viewModel.send()
                } label: {
                    Label("送る", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.large(background: .blue))

                Button("修正する") {
                    showConfirmation = false
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
    }
}
