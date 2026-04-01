import Foundation
import Observation

/// 子側の予定入力ViewModel（GUIテンプレートベース）
/// 電車・職場など声を出せない環境での操作を前提に、タップのみで完結する設計
@Observable
@MainActor
final class FamilyInputViewModel {

    // MARK: - 送信状態

    enum SendState: Equatable {
        case idle
        case sending
        case sent
        case error(String)
    }

    // MARK: - 入力フィールド

    /// 選択されたテンプレート（nilなら自由入力）
    var selectedTemplate: EventTemplate?
    /// タイトル（テンプレート選択で自動入力、自由入力も可）
    var title: String = ""
    /// 日時（デフォルト: 明日の9時）
    var fireDate: Date = Calendar.current.date(
        byAdding: .day, value: 1,
        to: Calendar.current.startOfDay(for: Date())
    ).map { Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: $0)! } ?? Date()
    /// 事前通知タイミング（分）
    var preNotificationMinutes: Int = 15
    /// 音声キャラクター
    var voiceCharacter: VoiceCharacter = .femaleConcierge
    /// メモ（任意）
    var note: String = ""
    /// 送信先の家族リンクID
    var familyLinkId: String

    var sendState: SendState = .idle

    private let service: FamilyScheduling

    init(familyLinkId: String, service: FamilyScheduling? = nil) {
        self.familyLinkId = familyLinkId
        self.service = service ?? FamilyRemoteService.shared
    }

    // MARK: - テンプレート選択

    func selectTemplate(_ template: EventTemplate) {
        selectedTemplate = template
        if let preset = template.defaultTitle {
            title = preset
        }
        // custom の場合はタイトルをクリアして自由入力へ
        if template == .custom { title = "" }
    }

    func clearTemplate() {
        selectedTemplate = nil
        title = ""
    }

    // MARK: - 確認テキスト生成（思いやりプレビュー）

    var previewText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）HH時mm分"
        let dateStr = formatter.string(from: fireDate)
        let minuteStr = preNotificationMinutes == 0 ? "時間ちょうど" : "\(preNotificationMinutes)分前"
        return "この予定を送ると、\(dateStr)の\(minuteStr)に「\(trimmedTitle)」とアラームが鳴ります。よろしいですか？"
    }

    var isReadyToSend: Bool {
        // レビュー指摘 #3: sendState == .sending のガードを追加。
        // 通信中に連打すると同じ予定が家族に複数届くため、送信中は再送信不可にする。
        !trimmedTitle.isEmpty && fireDate > Date() && sendState != .sending
    }

    // MARK: - 送信

    func send() {
        guard isReadyToSend else { return }
        sendState = .sending

        Task {
            do {
                // デバイス登録を確実に済ませてから送信（familyLinkIdからターゲットをサービス側で解決）
                _ = try await service.ensureDeviceRegistered()
                let payload = RemoteEventPayload(
                    familyLinkId: familyLinkId,
                    title: trimmedTitle,
                    fireDate: fireDate,
                    preNotificationMinutes: preNotificationMinutes,
                    voiceCharacter: voiceCharacter.rawValue,
                    note: note.isEmpty ? nil : note
                )
                try await service.createRemoteEvent(payload)
                sendState = .sent
            } catch {
                sendState = .error("送信に失敗しました。もう一度お試しください。")
            }
        }
    }

    func reset() {
        selectedTemplate = nil
        title = ""
        note = ""
        sendState = .idle
        // 日付はリセットしない（次も同じ日が多いケースに配慮）
    }

    // MARK: - Private

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }
}
