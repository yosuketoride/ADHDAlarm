import SwiftUI

/// オンボーディング Step 1: 掴み
/// フクロウキャラクターとSiriの呼び方カードで価値を伝える
struct HookView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.06, blue: 0.18).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 32)

                    // フクロウ + マイクのアイコン
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 160, height: 160)
                        // フクロウは枠より少し小さくして余白を確保
                        Image("OwlIcon")
                            .resizable().scaledToFit()
                            .frame(width: 130, height: 130)
                        // マイクを右下にオーバーレイ（アプリのメイン入力手段を示す）
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.4), radius: 6, y: 3)
                            .offset(x: 50, y: 50)
                    }
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.7)

                    // メインコピー
                    VStack(spacing: 12) {
                        Text("声で入れて、声で鳴る。")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("アプリのマイクボタンに話しかけるだけ。\n予定の登録からアラームのセットまで全部おまかせ。")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .padding(.horizontal, 24)

                    // Siri呼び方カード（ボーナス機能として紹介）
                    siriCard(
                        color: .blue,
                        icon: "🎙️",
                        label: "さらにSiriでも使えます（スマホに触らずに！）",
                        phrase: "「Hey Siri、こえメモにお願い」\n「Hey Siri、こえメモで予定を追加」"
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 16)
                }
            }
            .contentMargins(.bottom, 160, for: .scrollContent)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.3)) {
                appeared = true
            }
        }
    }

    private func siriCard(color: Color, icon: String, label: String, phrase: String) -> some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.title2)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text(phrase)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.25))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    HookView()
}
