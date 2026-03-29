import SwiftUI

/// 時間帯に応じた背景色オーバーレイ
/// systemBackground の上に薄い色を重ねてダークモード互換を維持する
struct TimeOfDayBackground: View {
    var body: some View {
        Color(.systemBackground)
            .overlay(timeOfDayColor.opacity(timeOfDayOpacity))
            .animation(.easeInOut(duration: 1.2), value: timeOfDayColor)
    }

    private var hour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var timeOfDayColor: Color {
        switch hour {
        case 5..<11:  return .morning    // 朝: soft blue
        case 11..<17: return .afternoon  // 昼: pale yellow
        case 17..<21: return .evening    // 夕: warm orange
        default:      return .night      // 夜: soft indigo
        }
    }

    private var timeOfDayOpacity: Double {
        switch hour {
        case 5..<11:  return 0.15
        case 11..<17: return 0.12
        case 17..<21: return 0.15
        default:      return 0.20
        }
    }
}
