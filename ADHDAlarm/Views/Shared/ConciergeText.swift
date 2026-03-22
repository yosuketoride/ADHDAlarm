import SwiftUI

/// コンシェルジュ口調（です・ます調）のマイクロコピー表示コンポーネント
struct ConciergeText: View {
    let message: String
    var font: Font = .body

    var body: some View {
        Text(message)
            .font(font)
            .foregroundStyle(Color.themeSecondary)
            .multilineTextAlignment(.center)
    }
}
