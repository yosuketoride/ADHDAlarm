import SwiftUI

/// コンシェルジュ口調（です・ます調）のマイクロコピー表示コンポーネント
struct ConciergeText: View {
    let message: String
    var font: Font = .body

    var body: some View {
        Text(message)
            .font(font)
            // レビュー指摘: Color(.secondaryLabel) はUIKit依存。SwiftUIネイティブな .secondary を使う。
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}
