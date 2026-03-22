import SwiftUI

/// オンボーディング Step 4: ウィジェット設置ガイド
/// 4ステップの操作手順をアニメーションで視覚的に示す（テキスト説明より直感的）
struct WidgetGuideView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
            // 見出し
            VStack(spacing: 12) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 52))
                    .foregroundStyle(.blue)

                Text("最後の仕上げです！")
                    .font(.title2.weight(.bold))

                VStack(spacing: 6) {
                    Label("アプリを開かずに次の予定を確認", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Label("ロック画面・ホーム画面から即アクセス", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 4)
            }

            // 操作手順アニメーション（PhaseAnimatorで4フェーズをループ）
            PhaseAnimator(WidgetInstallPhase.allCases, trigger: true) { phase in
                WidgetInstallAnimationView(phase: phase)
                    .frame(height: 180)
                    .padding(.horizontal, 32)
            } animation: { _ in
                .spring(duration: 2.0)
            }

            Text("あとで設置することもできます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 32)
        }
        .contentMargins(.bottom, 160, for: .scrollContent)
    }
}

// MARK: - アニメーションフェーズ

enum WidgetInstallPhase: CaseIterable {
    case longPress   // ホーム画面を長押し
    case plusButton  // 「+」ボタンが出現
    case selectApp   // アプリを選択
    case addWidget   // ウィジェットを追加
}

// MARK: - 各フェーズのアニメーションView

struct WidgetInstallAnimationView: View {
    let phase: WidgetInstallPhase

    var body: some View {
        VStack(spacing: 16) {
            // iPhoneフレーム
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                    .frame(width: 140, height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.systemGray3), lineWidth: 1.5)
                    )

                // フェーズごとの内部コンテンツ
                switch phase {
                case .longPress:
                    longPressContent
                case .plusButton:
                    plusButtonContent
                case .selectApp:
                    selectAppContent
                case .addWidget:
                    addWidgetContent
                }
            }

            // 説明テキスト
            Text(phase.description)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
    }

    // フェーズ1: 長押しジェスチャー
    private var longPressContent: some View {
        ZStack {
            // アプリアイコングリッド
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(22)), count: 4), spacing: 8) {
                ForEach(0..<8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 22, height: 22)
                }
            }
            // 指アイコン（長押し）
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
                .offset(x: 20, y: 20)
        }
    }

    // フェーズ2: 「+」ボタン出現
    private var plusButtonContent: some View {
        ZStack(alignment: .topLeading) {
            // 揺れているアイコングリッド（振動エフェクト風）
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(22)), count: 4), spacing: 8) {
                ForEach(0..<8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 22, height: 22)
                }
            }
            // 「+」ボタン
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(radius: 3)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
            }
            .offset(x: -8, y: -10)
        }
        .padding(8)
    }

    // フェーズ3: アプリ選択
    private var selectAppContent: some View {
        VStack(spacing: 4) {
            // アプリリスト風
            ForEach(["こえメモ", "他のアプリ", "他のアプリ"], id: \.self) { name in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(name == "こえメモ" ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                    Text(name)
                        .font(.system(size: 9))
                        .foregroundStyle(name == "こえメモ" ? .primary : .secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(name == "こえメモ" ? Color.blue.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(8)
    }

    // フェーズ4: ウィジェット追加
    private var addWidgetContent: some View {
        ZStack {
            // ウィジェットプレビュー
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.15))
                .frame(width: 80, height: 60)
                .overlay(
                    VStack(spacing: 2) {
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        Text("15:00")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                )
            // 「追加」チェック
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
                .offset(x: 36, y: -26)
        }
    }
}

extension WidgetInstallPhase {
    var description: String {
        switch self {
        case .longPress:  return "ホーム画面を長押し"
        case .plusButton: return "左上の「＋」をタップ"
        case .selectApp:  return "「こえメモ」を選ぶ"
        case .addWidget:  return "サイズを選んで追加！"
        }
    }
}
