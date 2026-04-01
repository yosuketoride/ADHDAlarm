import Foundation

/// 音声ファイル生成を抽象化するプロトコル
protocol VoiceSynthesizing {
    /// テキストから.cafファイルを生成し、そのURLを返す
    /// - Parameters:
    ///   - text: 読み上げテキスト（例: 「お時間です。あと15分でカフェのご予定ですよ。」）
    ///   - character: 音声キャラクター
    ///   - alarmID: ファイル名に使用するID
    nonisolated func generateAudio(text: String, character: VoiceCharacter, alarmID: UUID, eventTitle: String) async throws -> URL

    /// 生成済み音声ファイルを削除する（アラーム削除時のクリーンアップ）
    nonisolated func deleteAudio(alarmID: UUID)
}

extension VoiceSynthesizing {
    /// eventTitle省略時のデフォルト実装（既存の呼び出し元との互換性維持）
    nonisolated func generateAudio(text: String, character: VoiceCharacter, alarmID: UUID) async throws -> URL {
        try await generateAudio(text: text, character: character, alarmID: alarmID, eventTitle: "")
    }
}

/// 音声キャラクター設定
enum VoiceCharacter: String, CaseIterable, Codable {
    case femaleConcierge = "female_concierge"   // コンシェルジュ（女性）: 落ち着いた女性の声
    case maleButler = "male_butler"             // 執事（男性）: 安心感のある男性の声
    case customRecording = "custom_recording"   // 家族の生声（PRO）: ユーザーが録音した音声

    var displayName: String {
        switch self {
        case .femaleConcierge:  return "さくら（やさしい声）"
        case .maleButler:       return "タクト（落ち着いた声）"
        case .customRecording:  return "家族の生声"
        }
    }

    /// AVSpeechSynthesisVoice の識別子（日本語）
    var voiceIdentifier: String {
        switch self {
        case .femaleConcierge:  return "ja-JP"
        case .maleButler:       return "ja-JP"
        case .customRecording:  return "ja-JP"  // フォールバック用（録音がない場合のみ使用）
        }
    }
}
