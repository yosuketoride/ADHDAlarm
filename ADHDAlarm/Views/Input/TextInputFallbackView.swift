import SwiftUI

/// テキスト入力によるフォールバック
/// 音声入力が難しいユーザーや静かな環境向け
struct TextInputFallbackView: View {
    // レビュー指摘: @Observable な参照型に @State は不要（観察は自動で行われる）。
    // @State を付けると外部から新しいインスタンスを渡しても初回の値が永続化される。
    var viewModel: InputViewModel
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
                // レビュー指摘: axis: .vertical の TextField では .onSubmit は発火しない（デッドコード）。削除。

            // 解析ボタン
            Button {
                submitText()
            } label: {
                Label("よみとる", systemImage: "text.viewfinder")
            }
            .buttonStyle(.large(background: .blue))
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onAppear { isFocused = true }
    }

    private func submitText() {
        // レビュー指摘: .whitespaces では改行が除去されない。.whitespacesAndNewlines を使う。
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.parse(text: trimmed)
        isFocused = false
    }
}
