import Foundation

// MARK: - ウィジェット用ふくろうコメント（120パターン）
// PersonHomeViewModel.swift の greeting 辞書と同じ内容をWidget Extension用に複製

struct WidgetOwlComments {

    // MARK: - 時間帯
    enum TimeSlot {
        case morning, afternoon, evening, night

        static var current: TimeSlot { TimeSlot(from: Date()) }

        init(from date: Date) {
            let h = Calendar.current.component(.hour, from: date)
            switch h {
            case 5..<12:  self = .morning
            case 12..<17: self = .afternoon
            case 17..<21: self = .evening
            default:      self = .night
            }
        }
    }

    // MARK: - 気分（アラーム状況から決める）
    enum OwlMood {
        case normal, happy, worried, sleepy

        /// アラームまでの時間と状況から気分を判定
        static func from(alarm: WidgetAlarmEvent?) -> OwlMood {
            guard let alarm = alarm else { return .sleepy }
            let minutes = Int(alarm.fireDate.timeIntervalSinceNow / 60)
            if minutes < 0  { return .worried }
            if minutes < 15 { return .worried }
            if minutes > 120 { return .sleepy }
            return .normal
        }
    }

    // MARK: - ランダム選択（日時 + インデックスをシードに使うことで再現性を持たせる）
    static func pick(at date: Date, mood: OwlMood, seed: Int) -> String {
        let slot = TimeSlot(from: date)
        let pool = comments[slot]?[mood] ?? comments[.morning]![.normal]!
        return pool[abs(seed) % pool.count]
    }

    // MARK: - 120パターン辞書（PersonHomeViewModel.swift から移植）
    // 各時間帯 × 各気分 × 6パターン = 4 × 5 × 6 = 120
    // ※ウィジェットではふくろう名は「ふくろう」固定（App Groupから取得しない簡略版）
    static let comments: [TimeSlot: [OwlMood: [String]]] = [
        .morning: [
            .normal: [
                "おはようございます！",
                "今日もいい1日にしようね",
                "朝ごはんは食べた？",
                "今日もよろしくね！",
                "いい朝だね！",
                "今日も一緒にがんばろう",
            ],
            .happy: [
                "わーい、おはよう！",
                "今日も一緒に頑張ろうね！",
                "今日も元気に行こう！",
                "うれしいな、おはよう！",
                "いい朝だね！",
                "今日も楽しみだよ！",
            ],
            .worried: [
                "大丈夫？ちゃんと起きられた？",
                "何か急ぎの予定あったっけ？",
                "今日の予定、確認できてる？",
                "忘れ物ない？出かける前にチェックしてね",
                "急ぎの予定、ギリギリじゃない？",
                "朝から焦らなくていいよ、落ち着いてね",
            ],
            .sleepy: [
                "眠い…おはよう…",
                "ゆっくり目が覚めてきたかな？",
                "まだ眠そう…コーヒー飲んだ？",
                "のんびり起きていいよ",
                "目が覚めたら教えてね",
                "眠いときは無理しないでね",
            ],
        ],
        .afternoon: [
            .normal: [
                "こんにちは！",
                "お昼はゆっくりできてる？",
                "午後もよろしくね！",
                "いい午後だね！",
                "ちゃんとお昼ご飯食べた？",
                "午後も一緒だよ！",
            ],
            .happy: [
                "今日も調子いいね！",
                "午後もがんばろう！",
                "すごいね、元気いっぱい！",
                "一緒に午後も乗り越えよう！",
                "今日はいい1日になりそうだね！",
                "うれしそうだね！一緒に楽しもう",
            ],
            .worried: [
                "急ぎの予定、忘れてない？",
                "少し休んだ方がいいかも",
                "今日の予定はちゃんと進んでる？",
                "無理しすぎてない？",
                "ちょっと疲れてない？休憩もいいよ",
                "大丈夫？水分はちゃんと取ってね",
            ],
            .sleepy: [
                "お昼眠い…",
                "ちょっとひと休みしようか",
                "お昼過ぎは眠くなるよね",
                "少し目を閉じてみよっか",
                "眠いときは無理しないでね",
                "短い昼寝もいいかもね",
            ],
        ],
        .evening: [
            .normal: [
                "お疲れ様です！",
                "今日もよく頑張ったね",
                "夕方になったね、少し休んで",
                "今日も1日お疲れ様！",
                "夕方の風が気持ちいいね",
                "一緒にのんびりしようか",
            ],
            .happy: [
                "夕方も元気だね！",
                "今日一日よく頑張ったよ！",
                "いい顔してるね！",
                "今日もよく頑張ったね、えらい！",
                "夕暮れ、好きだな",
                "今日もいい1日だったね！",
            ],
            .worried: [
                "まだ終わってない予定ある？",
                "急がなくていいよ、ゆっくりね",
                "夜遅くなりそう？大丈夫？",
                "疲れてない？無理しないでね",
                "明日の準備、余裕あるうちにしておこうね",
                "焦らなくていいよ、一つずつやっていこう",
            ],
            .sleepy: [
                "眠くなってきた…",
                "今日はもうゆっくりしてね",
                "夕方は眠くなるよね",
                "ゆっくりお風呂に入ってね",
                "今日のうちに早めに休もうね",
                "疲れたら無理せず休んでいいよ",
            ],
        ],
        .night: [
            .normal: [
                "こんばんは！",
                "今夜もお疲れ様",
                "夜は静かでいいね",
                "こんばんは！ゆっくりしてね",
                "今日も一日ありがとう",
                "夜も一緒に過ごすよ",
            ],
            .happy: [
                "夜も元気！？すごいね",
                "今日もよく頑張ったね！",
                "夜も楽しそうだね！",
                "いい夜だね！",
                "今日もよく頑張ったよ、えらい！",
                "夜も笑顔でいいね！",
            ],
            .worried: [
                "遅くまで起きてて大丈夫？",
                "明日の予定は確認できてる？",
                "夜更かしはほどほどにね",
                "明日の準備、できてる？",
                "ちゃんと眠れそう？",
                "夜中に無理しないでね",
            ],
            .sleepy: [
                "眠い…おやすみ…",
                "早めに休んでね",
                "そろそろ寝る時間かな",
                "おやすみ、ゆっくり休んでね",
                "今日もお疲れ様、もう眠っていいよ",
                "ぐっすり眠れるといいね",
            ],
        ],
    ]
}
