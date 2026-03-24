import SwiftUI

/// 事前通知タイミング選択（シングル選択: 無料 / マルチ選択: PRO）
struct PreNotificationPicker: View {
    @Binding var selection: Set<Int>
    let isPro: Bool
    var onUpgradeTapped: () -> Void = {}

    /// プリセット（0 = ジャスト、60 = 1時間前）
    private let presets = [0, 1, 5, 10, 15, 30, 60]

    /// カスタム入力用
    @State private var showCustomInput = false
    @State private var customText = ""
    @FocusState private var customFocused: Bool

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

            // プリセットチップ（3列グリッド）
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(presets, id: \.self) { minutes in
                    minuteChip(minutes)
                }
                // 「その他」チップ
                otherChip
            }

            // カスタム入力フィールド（「その他」タップ後に展開）
            if showCustomInput {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        TextField("例: 45", text: $customText)
                            .keyboardType(.numberPad)
                            .focused($customFocused)
                        Text("分前")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        applyCustomMinutes()
                    } label: {
                        Text("追加")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // カスタム分数が選択されている場合にバッジ表示
            let customSelected = selection.filter { !presets.contains($0) }
            if !customSelected.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    ForEach(customSelected.sorted(), id: \.self) { m in
                        Text("\(m)分前")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                            .onTapGesture {
                                selection.remove(m)
                            }
                    }
                    Text("タップで削除")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.spring(duration: 0.25), value: showCustomInput)
    }

    // MARK: - チップ

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

    private var otherChip: some View {
        Button {
            if isPro {
                withAnimation { showCustomInput.toggle() }
                if showCustomInput { customFocused = true }
            } else {
                onUpgradeTapped()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: showCustomInput ? "chevron.up" : "pencil")
                    .font(.system(size: 22, weight: .bold))
                Text("その他")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isPro ? (showCustomInput ? Color.blue : .primary) : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(showCustomInput ? Color.blue.opacity(0.12) : Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if !isPro {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - ロジック

    private func handleTap(minutes: Int, isSelected: Bool) {
        if isPro {
            if isSelected {
                if selection.count > 1 { selection.remove(minutes) }
            } else {
                selection.insert(minutes)
            }
        } else {
            if !isSelected { selection = [minutes] }
        }
    }

    private func applyCustomMinutes() {
        guard let m = Int(customText.trimmingCharacters(in: .whitespaces)),
              m > 0, m <= 1440 else { return }
        if isPro {
            selection.insert(m)
        } else {
            selection = [m]
        }
        customText = ""
        customFocused = false
        withAnimation { showCustomInput = false }
    }
}
