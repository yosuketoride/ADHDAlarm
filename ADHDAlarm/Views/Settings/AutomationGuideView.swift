import SwiftUI

/// ショートカット・オートメーション設定ガイド
///
/// iOSの「ショートカット」アプリを使って SyncIntent を自動実行する方法を、
/// 番号付きカードで分かりやすく説明する。
struct AutomationGuideView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ヘッダー
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)

                    Text("魔法の自動化を設定しましょう")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("iPhoneの「ショートカット」アプリを使うと、毎日決まった時間にアラームを自動でお掃除（更新）できます。設定は一度だけ！")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // ステップカード
                VStack(spacing: 16) {
                    ForEach(AutomationStep.allCases) { step in
                        AutomationStepCard(step: step)
                    }
                }

                // おすすめトリガーのヒント
                VStack(alignment: .leading, spacing: 10) {
                    Label("おすすめのタイミング", systemImage: "lightbulb.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)

                    BulletRow(text: "毎日 午前1:00（眠っている間に自動更新）")
                    BulletRow(text: "充電器に繋いだとき")
                    BulletRow(text: "睡眠モード解除時（朝起きたとき）")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationTitle("自動化の設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ステップデータ

enum AutomationStep: String, CaseIterable, Identifiable {
    case openShortcuts
    case tapAutomation
    case createAutomation
    case chooseTrigger
    case addAction
    case done

    var id: String { rawValue }

    var stepNumber: Int {
        switch self {
        case .openShortcuts:    return 1
        case .tapAutomation:    return 2
        case .createAutomation: return 3
        case .chooseTrigger:    return 4
        case .addAction:        return 5
        case .done:             return 6
        }
    }

    var title: String {
        switch self {
        case .openShortcuts:    return "「ショートカット」アプリを開く"
        case .tapAutomation:    return "下の「オートメーション」タブをタップ"
        case .createAutomation: return "右上の「＋」をタップ"
        case .chooseTrigger:    return "実行タイミングを選ぶ"
        case .addAction:        return "「カレンダーとアラームを同期する」を追加"
        case .done:             return "「完了」を押せば設定完了！"
        }
    }

    var description: String {
        switch self {
        case .openShortcuts:
            return "iPhoneに最初から入っているアプリです。見つからない場合はApp Storeで「ショートカット」を検索してください。"
        case .tapAutomation:
            return "画面下のタブから「オートメーション」を選んでください。"
        case .createAutomation:
            return "右上の「＋」ボタンをタップして新しいオートメーションを作ります。"
        case .chooseTrigger:
            return "「毎日」を選び、時刻を「午前1:00」に設定するのがおすすめです。"
        case .addAction:
            return "「アクションを追加」→「アプリ」→「声メモアラーム」→「カレンダーとアラームを同期する」を選んでください。"
        case .done:
            return "これで、寝ている間に自動でお掃除してくれます！設定は最初の1回だけです。"
        }
    }
}

// MARK: - ステップカード

private struct AutomationStepCard: View {
    let step: AutomationStep

    private var isDone: Bool { step == .done }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // ステップ番号バッジ
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : Color.blue)
                    .frame(width: 40, height: 40)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step.stepNumber)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            // テキスト
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.callout.weight(.semibold))
                Text(step.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - 箇条書き行

private struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
