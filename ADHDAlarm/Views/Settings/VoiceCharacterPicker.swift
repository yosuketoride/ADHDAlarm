import SwiftUI
import AVFoundation

/// 音声キャラクター選択（コンパクト・リスト行スタイル）
struct VoiceCharacterPicker: View {
    @Binding var selection: VoiceCharacter
    let isPro: Bool
    var onUpgradeTapped: (() -> Void)?

    @Environment(AppState.self) private var appState
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var playingCharacter: VoiceCharacter?
    // レビュー指摘: 連続タップ時の競合を防ぐためTaskの参照を保持してキャンセルする
    @State private var previewTask: Task<Void, Never>?

    private let sampleText = "お時間です。準備はよろしいですか？"
    private let characters: [VoiceCharacter] = [.femaleConcierge, .maleButler, .customRecording]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(characters, id: \.self) { character in
                characterRow(character)
                if character != characters.last {
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    private func characterRow(_ character: VoiceCharacter) -> some View {
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
            HStack(spacing: Spacing.md) {
                // 選択インジケーター（モノクロアイコン背景と同じフレームサイズ）
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.blue : Color(.systemGray3))
                    .frame(width: 28, height: 28)

                // キャラクター名
                Text(character.displayName)
                    .font(.body)
                    .foregroundStyle(isEnabled ? .primary : .secondary)

                Spacer()

                // PRO バッジ（ロック中のみ）
                if !isEnabled {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.owlAmber)
                        .clipShape(Capsule())
                }

                // 試聴ボタン（カスタム録音以外・有効時のみ）
                if character != .customRecording && isEnabled {
                    Button {
                        playPreview(for: character)
                    } label: {
                        Label(isPlaying ? "停止" : "試聴",
                              systemImage: isPlaying ? "stop.fill" : "play.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: ComponentSize.settingRow)
            .padding(.horizontal, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func playPreview(for character: VoiceCharacter) {
        if playingCharacter == character {
            synthesizer.stopSpeaking(at: .immediate)
            playingCharacter = nil
            return
        }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = VoiceFileGenerator.makeUtterance(
            text: sampleText,
            character: character,
            isClearVoiceEnabled: appState.isClearVoiceEnabled
        )

        playingCharacter = character
        synthesizer.speak(utterance)

        previewTask?.cancel()
        previewTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            if playingCharacter == character {
                playingCharacter = nil
            }
        }
    }
}
