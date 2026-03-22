import Foundation

/// NLParserの解析結果
struct ParsedInput: Equatable {
    /// 抽出された予定タイトル（フィラー語除去済み）
    let title: String
    /// 抽出された予定日時
    let fireDate: Date
}
