import SwiftUI

/// 事前通知タイミング選択（シングル選択: 無料 / マルチ選択: PRO）
struct PreNotificationPicker: View {
    @Binding var selection: Set<Int>
    let isPro: Bool
    var onUpgradeTapped: () -> Void = {}

    /// 0 = ジャスト（予定時刻ぴったり）、60 = 1時間前
    private let options = [0, 1, 5, 10, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("予定の何分前に通知しますか？")
                    .font(.headline)
                Spacer()
                if isPro {
                    Text("複数選択可")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }

            // 均一サイズのチップグリッド（3列）
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(options, id: \.self) { minutes in
                    minuteChip(minutes)
                }
            }
        }
    }

    private func minuteChip(_ minutes: Int) -> some View {
        let isSelected = selection.contains(minutes)
        return Button {
            handleTap(minutes: minutes, isSelected: isSelected)
        } label: {
            VStack(spacing: 2) {
                Text(minutes == 60 ? "1" : "\(minutes)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text(minutes == 0 ? "ジャスト" : minutes == 60 ? "時間前" : "分前")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if isSelected && isPro && selection.count > 1 {
                    // PRO複数選択時にチェックマーク表示
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func handleTap(minutes: Int, isSelected: Bool) {
        if isPro {
            // PRO: 複数選択トグル（最低1つは残す）
            if isSelected {
                if selection.count > 1 {
                    selection.remove(minutes)
                }
            } else {
                selection.insert(minutes)
            }
        } else {
            // 無料: 単一選択のみ（選択済みの再タップは無視）
            // ※ 再タップ時にペイウォールを開くと、閉じた後にリストがフリーズするため
            if !isSelected {
                selection = [minutes]
            }
        }
    }
}
