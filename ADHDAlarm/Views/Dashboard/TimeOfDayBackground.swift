import SwiftUI

/// 時間帯に応じた背景色オーバーレイ
/// systemBackground の上に薄い色を重ねてダークモード互換を維持する
struct TimeOfDayBackground: View {
    var body: some View {
        // レビュー指摘: computed property 内で Date() を呼ぶだけでは SwiftUI は
        // 再描画トリガーを持たないため、アプリ起動後に時刻をまたいでも背景色が
        // フリーズしたまま更新されない。TimelineView で 60 秒ごとに強制再評価する。
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let hour = Calendar.current.component(.hour, from: context.date)
            Color(.systemBackground)
                .overlay(timeOfDayColor(for: hour).opacity(timeOfDayOpacity(for: hour)))
                .animation(.easeInOut(duration: 1.2), value: hour)
        }
    }

    private func timeOfDayColor(for hour: Int) -> Color {
        switch hour {
        case 5..<11:  return .morning    // 朝: soft blue
        case 11..<17: return .afternoon  // 昼: pale yellow
        case 17..<21: return .evening    // 夕: warm orange
        default:      return .night      // 夜: soft indigo
        }
    }

    private func timeOfDayOpacity(for hour: Int) -> Double {
        switch hour {
        case 5..<11:  return 0.15
        case 11..<17: return 0.12
        case 17..<21: return 0.15
        default:      return 0.20
        }
    }
}
