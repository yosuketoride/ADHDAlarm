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

    /// このカテゴリに判定するキーワード一覧
    var keywords: [String] {
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

    /// 録音例文（ガイド用）
    var exampleScript: String {
        switch self {
        case .medicine:
            return "「おばあちゃん、お薬の時間だよ！忘れずにね。」"
        case .outing:
            return "「もうすぐ出かける時間だよ！準備はできてる？」"
        case .work:
            return "「会議の時間だよ！遅れないようにね。」"
        case .meal:
            return "「ご飯の時間だよ！一緒に食べようね。」"
        case .hospital:
            return "「病院の時間だよ！忘れ物ないか確認してね。」"
        case .other:
            return "「大切な予定の時間だよ！忘れないでね。」"
        }
    }

    /// Library/Sounds/ 以下のファイル名
    var fileName: String { "custom_voice_\(rawValue).caf" }

    // MARK: - カテゴリ自動判定

    /// 予定タイトルからカテゴリを判定する（キーワードマッチ）
    static func match(for title: String) -> VoiceCategory {
        for category in VoiceCategory.allCases where category != .other {
            for keyword in category.keywords {
                if title.contains(keyword) { return category }
            }
        }
        return .other
    }
}
