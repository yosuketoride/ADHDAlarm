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
        // レビュー指摘: 残り時間が長い場合でも by:1 で毎秒更新するとバッテリーを無駄消耗する。
        // 外側の 60 秒 TimelineView で「残り10分未満かどうか」の帯域を判定し、
        // 10分未満のときだけ内側の 1 秒 TimelineView に切り替える二重構造にする。
        TimelineView(.periodic(from: .now, by: 60)) { outer in
            let approx = alarm.fireDate.timeIntervalSince(outer.date)
            if approx < 600 {
                // 残り10分未満: 1秒更新（秒単位表示・ADHD向け仕様）
                TimelineView(.periodic(from: .now, by: 1)) { inner in
                    let remaining = alarm.fireDate.timeIntervalSince(inner.date)
                    if remaining < 60 {
                        urgentCountdown(remaining: remaining)
                    } else {
                        minuteSecondCountdown(remaining: remaining)
                    }
                }
            } else if approx < 3600 {
                // 残り10〜59分: 「あと約○分」（60秒更新）
                TimelineView(.periodic(from: .now, by: 60)) { inner in
                    approximateMinuteView(remaining: alarm.fireDate.timeIntervalSince(inner.date))
                }
            } else {
                // 残り1時間以上: 「あと約○時間」（60秒更新）
                TimelineView(.periodic(from: .now, by: 60)) { inner in
                    approximateHourView(remaining: alarm.fireDate.timeIntervalSince(inner.date))
                }
            }
        }
    }

    // MARK: - 各表示形式

    /// 残り1分未満: 赤 + 「もうすぐです！」
    private func urgentCountdown(remaining: TimeInterval) -> some View {
        let s = Int(max(0, remaining)) % 60
        return VStack(spacing: 4) {
            timeUnit(value: s, label: "秒", size: 52, color: .red)
            Text("もうすぐです！")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.red)
        }
    }

    /// 残り10分未満: 分（大）＋秒（小）
    private func minuteSecondCountdown(remaining: TimeInterval) -> some View {
        let total = Int(max(0, remaining))
        let m = (total % 3600) / 60
        let s = total % 60
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            if m > 0 {
                timeUnit(value: m, label: "分", size: 52, color: .primary)
            }
            timeUnit(value: s, label: "秒", size: 28, color: .secondary)
        }
    }

    /// 残り10〜59分: ざっくり分表示
    private func approximateMinuteView(remaining: TimeInterval) -> some View {
        let m = Int(ceil(max(0, remaining) / 60))
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("あと約")
                .font(.title3)
                .foregroundStyle(.secondary)
            timeUnit(value: m, label: "分", size: 52, color: .primary)
        }
    }

    /// 残り1時間以上: ざっくり時間表示
    private func approximateHourView(remaining: TimeInterval) -> some View {
        let h = Int(ceil(max(0, remaining) / 3600))
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
