import SwiftUI
import AVFoundation

/// 音声キャラクター選択（PRO限定）
struct VoiceCharacterPicker: View {
    @Binding var selection: VoiceCharacter
    let isPro: Bool
    var onUpgradeTapped: (() -> Void)?

    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var playingCharacter: VoiceCharacter?

    private let sampleText = "お時間です。準備はよろしいですか？"

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
        let isPlaying  = playingCharacter == character

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

                // 試聴ボタン（カスタム録音以外）
                if character != .customRecording && isEnabled {
                    Button {
                        playPreview(for: character)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 10))
                            Text(isPlaying ? "停止" : "試聴")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
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

    private func playPreview(for character: VoiceCharacter) {
        if playingCharacter == character {
            // 同じキャラをタップ → 停止
            synthesizer.stopSpeaking(at: .immediate)
            playingCharacter = nil
            return
        }

        // 別キャラ or 停止中 → 停止してから新しい声を再生
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = VoiceFileGenerator.voice(for: character)
        utterance.rate  = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = character == .maleButler ? 0.85 : 1.05

        playingCharacter = character
        synthesizer.speak(utterance)

        // 再生終了後にフラグをリセット（3秒程度で終わるので余裕を持って5秒後）
        Task {
            try? await Task.sleep(for: .seconds(5))
            if playingCharacter == character {
                playingCharacter = nil
            }
        }
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
