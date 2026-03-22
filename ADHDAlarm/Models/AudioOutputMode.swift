import Foundation

/// 音声の出力先設定
enum AudioOutputMode: String, CaseIterable, Codable {
    /// iOS が自動選択（イヤホン接続時はイヤホン、それ以外はスピーカー）
    case automatic = "automatic"
    /// 常にスピーカーから出力（イヤホン接続中でもスピーカー）
    case speaker = "speaker"

    var displayName: String {
        switch self {
        case .automatic: return "自動"
        case .speaker:   return "スピーカー強制"
        }
    }

    var description: String {
        switch self {
        case .automatic: return "イヤホン時はイヤホン、それ以外はスピーカー"
        case .speaker:   return "イヤホンをしていてもスピーカーから鳴らす"
        }
    }
}
