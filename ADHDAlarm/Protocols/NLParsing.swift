import Foundation

/// 自然言語テキストの解析を抽象化するプロトコル
protocol NLParsing {
    /// テキストから予定タイトルと日時を抽出する
    /// - Returns: 解析成功時はParsedInput、解析不能な場合はnil
    func parse(text: String) -> ParsedInput?

    /// タイトルから絵文字を推定する
    func inferEmoji(from title: String) -> String?
}
