import SwiftUI

/// 音声キャラクター選択（PRO限定）
struct VoiceCharacterPicker: View {
    @Binding var selection: VoiceCharacter
    let isPro: Bool
    var onUpgradeTapped: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("音声キャラクター")
                    .font(.headline)
                if !isPro {
                    proTag
                }
            }

            HStack(spacing: 12) {
                characterCard(.femaleConcierge, icon: "person.fill",         label: "さくら\n（やさしい声）")
                characterCard(.maleButler,      icon: "person.bust",         label: "タクト\n（落ち着いた声）")
                characterCard(.customRecording, icon: "person.wave.2.fill",  label: "家族の\n生声")
            }
        }
    }

    private func characterCard(_ character: VoiceCharacter, icon: String, label: String) -> some View {
        let isSelected = selection == character
        let isEnabled  = isPro || character == .femaleConcierge

        return Button {
            if isEnabled {
                selection = character
            } else {
                onUpgradeTapped?()
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isSelected ? .white : (isEnabled ? .primary : .secondary))

                Text(label)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .white : (isEnabled ? .primary : .secondary))

                if !isEnabled {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var proTag: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue)
            .clipShape(Capsule())
    }
}
