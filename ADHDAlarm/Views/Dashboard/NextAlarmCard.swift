import SwiftUI

/// 次のアラームまでのカウントダウンを表示するカード（ADHD向け時間可視化）
/// 残り時間に応じて表示形式を変える — 秒単位の細かい更新はADHD層の不安を煽るため残り10分未満のみ
struct NextAlarmCard: View {
    let alarm: AlarmEvent

    var body: some View {
        VStack(spacing: 12) {
            Text("次のご予定まで")
                .font(.callout)
                .foregroundStyle(.secondary)

            countdownBody

            Text(alarm.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(alarm.fireDate.naturalJapaneseString)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - カウントダウン本体

    @ViewBuilder
    private var countdownBody: some View {
        let remaining = alarm.fireDate.timeIntervalSince(Date())

        if remaining <= 0 {
            // 時間を過ぎた
            Text("お時間です！")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.red)
        } else if remaining < 60 {
            // 残り1分未満: 秒カウントダウン + 強調メッセージ
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                urgentCountdown
            }
        } else if remaining < 600 {
            // 残り10分未満: 分＋秒カウントダウン（1秒更新）
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                minuteSecondCountdown
            }
        } else if remaining < 3600 {
            // 残り10〜59分: 「あと約○分」（60秒更新）
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                approximateMinuteView
            }
        } else {
            // 残り1時間以上: 「あと約○時間」（60秒更新）
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                approximateHourView
            }
        }
    }

    // MARK: - 各表示形式

    /// 残り1分未満: 赤 + 「もうすぐです！」
    private var urgentCountdown: some View {
        let remaining = max(0, alarm.fireDate.timeIntervalSince(Date()))
        let s = Int(remaining) % 60
        return VStack(spacing: 4) {
            timeUnit(value: s, label: "秒", size: 52, color: .red)
            Text("もうすぐです！")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.red)
        }
    }

    /// 残り10分未満: 分（大）＋秒（小）
    private var minuteSecondCountdown: some View {
        let remaining = max(0, alarm.fireDate.timeIntervalSince(Date()))
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            if m > 0 {
                timeUnit(value: m, label: "分", size: 52, color: .primary)
            }
            timeUnit(value: s, label: "秒", size: 28, color: .secondary)
        }
    }

    /// 残り10〜59分: ざっくり分表示
    private var approximateMinuteView: some View {
        let remaining = max(0, alarm.fireDate.timeIntervalSince(Date()))
        let m = Int(ceil(remaining / 60))
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("あと約")
                .font(.title3)
                .foregroundStyle(.secondary)
            timeUnit(value: m, label: "分", size: 52, color: .primary)
        }
    }

    /// 残り1時間以上: ざっくり時間表示
    private var approximateHourView: some View {
        let remaining = max(0, alarm.fireDate.timeIntervalSince(Date()))
        let h = Int(ceil(remaining / 3600))
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("あと約")
                .font(.title3)
                .foregroundStyle(.secondary)
            timeUnit(value: h, label: "時間", size: 52, color: .primary)
        }
    }

    // MARK: - 共通タイムユニット

    private func timeUnit(value: Int, label: String, size: CGFloat, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(value)")
                .font(.system(size: size, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
