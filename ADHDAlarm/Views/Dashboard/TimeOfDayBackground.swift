import SwiftUI

enum HomeBackgroundPhase {
    case dawn
    case day
    case sunset
    case night
}

struct HomeBackgroundPalette {
    let phase: HomeBackgroundPhase
    let top: Color
    let bottom: Color
    let glow: Color
    let boundary: Color
    let gradientOpacity: Double

    static func forDate(_ date: Date) -> HomeBackgroundPalette {
        let hour = Calendar.current.component(.hour, from: date)
        return forHour(hour)
    }

    static func forHour(_ hour: Int) -> HomeBackgroundPalette {
        switch hour {
        case 5..<8:
            return HomeBackgroundPalette(
                phase: .dawn,
                top: .dawnPink,
                bottom: .dawnPeach,
                glow: .white,
                boundary: .dawnBoundary,
                gradientOpacity: 0.82
            )
        case 8..<16:
            return HomeBackgroundPalette(
                phase: .day,
                top: .daySky,
                bottom: .dayBlue,
                glow: .white,
                boundary: .dayBoundary,
                gradientOpacity: 0.56
            )
        case 16..<20:
            return HomeBackgroundPalette(
                phase: .sunset,
                top: .sunsetAmber,
                bottom: .sunsetCoral,
                glow: .dawnPeach,
                boundary: .sunsetBoundary,
                gradientOpacity: 0.68
            )
        default:
            return HomeBackgroundPalette(
                phase: .night,
                top: .midnightInk,
                bottom: .midnightBlack,
                glow: .night,
                boundary: .midnightInk,
                gradientOpacity: 0.90
            )
        }
    }

    var usesLightUpperText: Bool {
        phase == .night
    }
}

/// 時間帯に応じた背景色オーバーレイ
/// systemBackground の上に薄い色を重ねてダークモード互換を維持する
struct TimeOfDayBackground: View {
    var previewHour: Int? = nil

    var body: some View {
        if let previewHour {
            backgroundLayer(for: .forHour(previewHour))
        } else {
            // レビュー指摘: computed property 内で Date() を呼ぶだけでは SwiftUI は
            // 再描画トリガーを持たないため、アプリ起動後に時刻をまたいでも背景色が
            // フリーズしたまま更新されない。TimelineView で 60 秒ごとに強制再評価する。
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let hour = Calendar.current.component(.hour, from: context.date)
                backgroundLayer(for: .forDate(context.date))
                    .animation(.easeInOut(duration: 1.2), value: hour)
            }
        }
    }

    private func backgroundLayer(for palette: HomeBackgroundPalette) -> some View {
        ZStack {
            Color(.systemBackground)

            LinearGradient(
                colors: [
                    palette.top,
                    palette.bottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(palette.gradientOpacity)

            RadialGradient(
                colors: [
                    palette.glow.opacity(0.20),
                    Color.clear
                ],
                center: .top,
                startRadius: 28,
                endRadius: 420
            )
        }
    }
}
