import Foundation

/// NLParserの解析結果
struct ParsedInput: Equatable {
    /// 抽出された予定タイトル（フィラー語除去済み）
    let title: String
    /// 抽出された予定日時（繰り返し予定では最初の発火日時）
    let fireDate: Date
    /// 抽出された繰り返しルール（nilなら単発）
    var recurrenceRule: RecurrenceRule? = nil
    /// NLParserが日付を明示的に検出したか（falseなら時間のみの発話 → 確認カードで今日/明日トグルを表示）
    var hasExplicitDate: Bool = false
}
