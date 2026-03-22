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
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 140, height: 140)
                        VStack(spacing: 0) {
                            Text("🦉")
                                .font(.system(size: 72))
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.blue)
                                .offset(x: 28, y: -24)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.7)

                    // メインコピー
                    VStack(spacing: 12) {
                        Text("声で入れて、声で鳴る。")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("スマホに触らなくても、Siriに話しかけるだけで\n予定の登録からアラームのセットまで完了します。")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .padding(.horizontal, 24)

                    // Siri呼び方カード（どちらのフレーズでもOK）
                    siriCard(
                        color: .blue,
                        icon: "🎙️",
                        label: "こう呼びかけるだけ",
                        phrase: "「Hey Siri、声メモアラームにお願い」\n「Hey Siri、声メモアラームで予定を追加」"
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .padding(.horizontal, 20)

                    // 補足
                    Text("Siriに話しかけるだけで、カレンダーへの登録と\nアラームのセットが同時に完了します！")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(appeared ? 1 : 0)

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
