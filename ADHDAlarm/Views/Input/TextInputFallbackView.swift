import SwiftUI

/// テキスト入力によるフォールバック
/// 音声入力が難しいユーザーや静かな環境向け
struct TextInputFallbackView: View {
    @State var viewModel: InputViewModel
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // テキストフィールド
            TextField("「明日の15時にカフェ」と入力", text: $text, axis: .vertical)
                .font(.body)
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($isFocused)
                .onSubmit { submitText() }

            // 解析ボタン
            Button {
                submitText()
            } label: {
                Label("よみとる", systemImage: "text.viewfinder")
            }
            .buttonStyle(.large(background: .blue))
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .onAppear { isFocused = true }
    }

    private func submitText() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        viewModel.parse(text: trimmed)
        isFocused = false
    }
}
