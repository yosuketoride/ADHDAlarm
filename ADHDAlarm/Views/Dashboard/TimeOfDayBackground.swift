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

private struct HomeCelestialState {
    let symbolName: String
    let tint: Color
    let glowColor: Color
    let normalizedX: CGFloat
    let normalizedY: CGFloat
    let scale: CGFloat
    let opacity: Double
    let rotation: Double
    let showsStars: Bool
    let starOpacity: Double

    static func forDate(_ date: Date) -> HomeCelestialState {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        func normalizedProgress(startHour: Int, endHour: Int) -> Double {
            let totalMinutes = Double((endHour - startHour) * 60)
            let elapsedMinutes = Double((hour - startHour) * 60 + minute)
            return min(max(elapsedMinutes / totalMinutes, 0), 1)
        }

        func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
            start + (end - start) * CGFloat(progress)
        }

        switch hour {
        case 5..<8:
            let progress = normalizedProgress(startHour: 5, endHour: 8)
            let y = lerp(0.68, 0.30, progress) - CGFloat(sin(progress * .pi)) * 0.04
            return HomeCelestialState(
                symbolName: "sun.max.fill",
                tint: .yellow.opacity(0.92),
                glowColor: .white,
                normalizedX: lerp(0.14, 0.36, progress),
                normalizedY: y,
                scale: lerp(0.92, 1.04, progress),
                opacity: 0.72,
                rotation: -8
                    + (progress * 8),
                showsStars: false,
                starOpacity: 0
            )

        case 8..<16:
            let progress = normalizedProgress(startHour: 8, endHour: 16)
            let y = 0.24 - CGFloat(sin(progress * .pi)) * 0.10
            return HomeCelestialState(
                symbolName: "sun.max.fill",
                tint: .yellow.opacity(0.94),
                glowColor: .white,
                normalizedX: lerp(0.22, 0.80, progress),
                normalizedY: y,
                scale: 1.06,
                opacity: 0.70,
                rotation: 0,
                showsStars: false,
                starOpacity: 0
            )

        case 16..<20:
            let progress = normalizedProgress(startHour: 16, endHour: 20)
            let y = lerp(0.24, 0.64, progress) - CGFloat(sin(progress * .pi)) * 0.03
            return HomeCelestialState(
                symbolName: "sun.max.fill",
                tint: .orange.opacity(0.92),
                glowColor: .sunsetAmber,
                normalizedX: lerp(0.66, 0.90, progress),
                normalizedY: y,
                scale: lerp(1.02, 0.90, progress),
                opacity: 0.68,
                rotation: 10
                    - (progress * 14),
                showsStars: false,
                starOpacity: 0
            )

        default:
            let progress: Double
            if hour >= 20 {
                progress = min(max(Double((hour - 20) * 60 + minute) / Double(9 * 60), 0), 1)
            } else {
                progress = min(max(Double((hour + 4) * 60 + minute) / Double(9 * 60), 0), 1)
            }

            let y = 0.18 + CGFloat(sin(progress * .pi)) * 0.05
            return HomeCelestialState(
                symbolName: "moon.stars.fill",
                tint: .white.opacity(0.92),
                glowColor: .night,
                normalizedX: lerp(0.78, 0.54, progress),
                normalizedY: y,
                scale: 0.94,
                opacity: 0.62,
                rotation: -6,
                showsStars: true,
                starOpacity: 0.42
            )
        }
    }
}

/// 時間帯に応じた背景色オーバーレイ
/// systemBackground の上に薄い色を重ねてダークモード互換を維持する
struct TimeOfDayBackground: View {
    var previewHour: Int? = nil
    @State private var hasAnimatedIn = false

    var body: some View {
        if let previewHour {
            let previewDate = Self.previewDate(for: previewHour)
            backgroundLayer(
                for: .forHour(previewHour),
                celestial: .forDate(previewDate)
            )
        } else {
            // レビュー指摘: computed property 内で Date() を呼ぶだけでは SwiftUI は
            // 再描画トリガーを持たないため、アプリ起動後に時刻をまたいでも背景色が
            // フリーズしたまま更新されない。TimelineView で 60 秒ごとに強制再評価する。
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let hour = Calendar.current.component(.hour, from: context.date)
                backgroundLayer(
                    for: .forDate(context.date),
                    celestial: .forDate(context.date)
                )
                    .animation(.easeInOut(duration: 1.2), value: hour)
                    .animation(.easeInOut(duration: 1.2), value: context.date.timeIntervalSinceReferenceDate / 60)
            }
        }
    }

    private func backgroundLayer(
        for palette: HomeBackgroundPalette,
        celestial: HomeCelestialState
    ) -> some View {
        GeometryReader { proxy in
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

                celestialLayer(celestial, in: proxy.size)
            }
            .clipped()
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    hasAnimatedIn = true
                }
            }
        }
    }

    private func celestialLayer(_ state: HomeCelestialState, in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(state.glowColor.opacity(state.showsStars ? 0.14 : 0.18))
                .frame(width: state.showsStars ? 108 : 124, height: state.showsStars ? 108 : 124)
                .blur(radius: state.showsStars ? 18 : 24)
                .position(
                    x: size.width * state.normalizedX,
                    y: size.height * state.normalizedY
                )

            Image(systemName: state.symbolName)
                .font(.system(size: state.showsStars ? 34 : 42, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(state.tint)
                .rotationEffect(.degrees(state.rotation))
                .scaleEffect(hasAnimatedIn ? state.scale : state.scale * 0.92)
                .opacity(hasAnimatedIn ? state.opacity : 0)
                .position(
                    x: size.width * state.normalizedX,
                    y: size.height * state.normalizedY
                )

            if state.showsStars {
                ForEach(Array(nightStars(in: size).enumerated()), id: \.offset) { _, star in
                    Image(systemName: "sparkle")
                        .font(.system(size: star.size, weight: .medium))
                        .foregroundStyle(Color.white.opacity(state.starOpacity * star.opacity))
                        .opacity(hasAnimatedIn ? 1 : 0)
                        .scaleEffect(hasAnimatedIn ? 1 : 0.7)
                        .position(star.position)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func nightStars(in size: CGSize) -> [(position: CGPoint, size: CGFloat, opacity: Double)] {
        [
            (CGPoint(x: size.width * 0.18, y: size.height * 0.20), 14, 0.85),
            (CGPoint(x: size.width * 0.30, y: size.height * 0.13), 11, 0.68),
            (CGPoint(x: size.width * 0.64, y: size.height * 0.16), 12, 0.76),
            (CGPoint(x: size.width * 0.86, y: size.height * 0.24), 10, 0.58)
        ]
    }

    private static func previewDate(for hour: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}
