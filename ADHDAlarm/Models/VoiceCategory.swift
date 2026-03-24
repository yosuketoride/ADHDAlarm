import Foundation

/// 家族の生声を録音するカテゴリ（PRO機能）
/// 予定タイトルのキーワードから自動でカテゴリを判定し、対応する録音を再生する
enum VoiceCategory: String, CaseIterable, Codable {
    case medicine   = "medicine"   // お薬・服薬
    case outing     = "outing"     // お出かけ・外出
    case work       = "work"       // お仕事・会議
    case meal       = "meal"       // 食事・ご飯
    case hospital   = "hospital"   // 病院・受診
    case other      = "other"      // その他（デフォルト）

    var displayName: String {
        switch self {
        case .medicine: return "お薬・服薬"
        case .outing:   return "お出かけ"
        case .work:     return "お仕事・会議"
        case .meal:     return "食事・ご飯"
        case .hospital: return "病院・受診"
        case .other:    return "その他の予定"
        }
    }

    var emoji: String {
        switch self {
        case .medicine: return "💊"
        case .outing:   return "🚶"
        case .work:     return "💼"
        case .meal:     return "🍽️"
        case .hospital: return "🏥"
        case .other:    return "🦉"
        }
    }

    /// このカテゴリに判定するキーワード一覧（nonisolated: match(for:)から呼ぶため）
    nonisolated var keywords: [String] {
        switch self {
        case .medicine:
            return ["薬", "お薬", "くすり", "服薬", "飲み薬", "点眼", "インスリン"]
        case .outing:
            return ["出かけ", "外出", "散歩", "お出かけ", "出発", "帰宅"]
        case .work:
            return ["会議", "仕事", "打ち合わせ", "MTG", "ミーティング", "出社", "業務"]
        case .meal:
            return ["ご飯", "食事", "昼食", "夕食", "朝食", "昼ご飯", "夕ご飯", "朝ご飯",
                    "ランチ", "ディナー", "食べ", "おやつ"]
        case .hospital:
            return ["病院", "クリニック", "診察", "受診", "通院", "歯医者", "検査"]
        case .other:
            return []  // デフォルト（どれにも当てはまらない場合）
        }
    }

    /// 録音例文（シートのメインガイド用 — 最も使いやすい1文）
    var exampleScript: String {
        switch self {
        case .medicine:
            return "「おじいちゃん、朝のお薬の時間だよ！今日も元気でね。」"
        case .outing:
            return "「出発の時間だよ！スマホ、お財布、鍵は持った？いってらっしゃい！」"
        case .work:
            return "「もうすぐ会議の時間だよ！準備はOK？今日も応援してるよ！」"
        case .meal:
            return "「ご飯の時間だよ！一息ついて、しっかり食べてね。」"
        case .hospital:
            return "「今日は病院の日だよ！診察券と保険証、忘れずにカバンに入れてね。」"
        case .other:
            return "「予定の時間だよ！無理せず、自分のペースでやっていこうね！」"
        }
    }

    /// 録音ヒント集（録音ボタン下に表示する参考フレーズ）
    var scriptHints: [String] {
        switch self {
        case .medicine:
            return [
                "「おじいちゃん、朝のお薬の時間だよ！今日も元気でね。」（お孫さんより）",
                "「お薬の時間です！飲んだらチェックしてね。」（ご家族より）"
            ]
        case .outing:
            return [
                "「出発の時間だよ！スマホ、お財布、鍵は持った？いってらっしゃい！」",
                "「お出かけの時間です。ガスの元栓は閉めたかな？気をつけてね。」"
            ]
        case .work:
            return [
                "「もうすぐ会議の時間だよ！準備はOK？今日も応援してるよ！」",
                "「お仕事の時間です。今の作業に区切りをつけて、次へ向かいましょう。」"
            ]
        case .meal:
            return [
                "「ご飯の時間だよ！一息ついて、しっかり食べてね。」",
                "「食事の時間です。休むことも大切な仕事ですよ。」"
            ]
        case .hospital:
            return [
                "「今日は病院の日だよ！診察券と保険証、忘れずにカバンに入れてね。」",
                "「病院の時間です。早めに出発しておくと安心ですよ。」"
            ]
        case .other:
            return [
                "「予定の時間だよ！無理せず、自分のペースでやっていこうね！」",
                "「大切な予定の時間です。今日もお疲れさま。」"
            ]
        }
    }

    /// Library/Sounds/ 以下のファイル名（nonisolated: VoiceFileGeneratorのnonisolatedコンテキストから呼ぶため）
    nonisolated var fileName: String { "custom_voice_\(rawValue).caf" }

    // MARK: - カテゴリ自動判定

    /// 予定タイトルからカテゴリを判定する（キーワードマッチ）
    /// nonisolated: VoiceFileGeneratorのnonisolatedコンテキストから呼ぶため
    nonisolated static func match(for title: String) -> VoiceCategory {
        for category in VoiceCategory.allCases where category != .other {
            for keyword in category.keywords {
                if title.contains(keyword) { return category }
            }
        }
        return .other
    }
}
