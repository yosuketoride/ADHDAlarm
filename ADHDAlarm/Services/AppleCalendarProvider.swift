import Foundation
import EventKit

/// EventKitを使ったCalendarProviding実装
/// アプリが作成したイベントのみを対象にすることで、他カレンダーのノイズを完全排除する
final class AppleCalendarProvider: CalendarProviding {

    private let eventStore = EKEventStore()

    nonisolated init() {}

    // MARK: - CalendarProviding

    /// アプリが作成した予定をすべて取得する（マーカーで識別）
    func fetchAppEvents() async throws -> [AlarmEvent] {
        // 過去1日〜1年先までの範囲を対象
        let from = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let to   = Calendar.current.date(byAdding: .year, value: 1,  to: Date()) ?? Date()
        return try await fetchAppEvents(from: from, to: to)
    }

    /// 指定期間のアプリ作成予定を取得する
    func fetchAppEvents(from: Date, to: Date) async throws -> [AlarmEvent] {
        let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: nil)
        let ekEvents  = eventStore.events(matching: predicate)

        return ekEvents.compactMap { ekEvent -> AlarmEvent? in
            guard let notes = ekEvent.notes,
                  notes.contains(Constants.eventMarkerPrefix),
                  let uuid = extractUUID(from: notes) else {
                return nil  // マーカーなし → 他アプリが作成したイベント → 無視
            }

            return AlarmEvent(
                id: uuid,
                title: ekEvent.title ?? "",
                fireDate: ekEvent.startDate,
                eventKitIdentifier: ekEvent.eventIdentifier
            )
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    /// EventKitに予定を書き込む
    /// - Parameters:
    ///   - alarm: 書き込む予定
    ///   - calendarID: 書き込み先カレンダーID（nilならデフォルトカレンダー）
    /// - Returns: EKEvent.eventIdentifier
    @discardableResult
    func writeEvent(_ alarm: AlarmEvent, to calendarID: String?) async throws -> String {
        let ekEvent       = EKEvent(eventStore: eventStore)
        ekEvent.title     = alarm.title
        ekEvent.startDate = alarm.fireDate
        ekEvent.endDate   = alarm.fireDate.addingTimeInterval(3600)  // 1時間後を終了時刻に設定

        // 書き込み先カレンダーを決定（PRO版はcalendarIDで任意カレンダーを選択可能）
        if let calendarID,
           let calendar = eventStore.calendar(withIdentifier: calendarID) {
            ekEvent.calendar = calendar
        } else {
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
        }

        // アプリ作成イベントを識別するマーカーをnotesに埋め込む（人間が読める説明 + 機械識別マーカー）
        ekEvent.notes = "📱 忘れん坊アラームで登録\n\(Constants.eventMarker(for: alarm.id))"

        try eventStore.save(ekEvent, span: .thisEvent)
        return ekEvent.eventIdentifier
    }

    /// EventKitから予定を削除する
    func deleteEvent(eventKitIdentifier: String) async throws {
        guard let ekEvent = eventStore.event(withIdentifier: eventKitIdentifier) else {
            return  // すでに存在しない場合は正常扱い
        }
        try eventStore.remove(ekEvent, span: .thisEvent)
    }

    /// 利用可能なカレンダー一覧（PRO版のカレンダー選択に使用）
    func availableCalendars() async throws -> [CalendarInfo] {
        eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }  // 書き込み可能なものだけ
            .map { calendar in
                CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    colorHex: calendar.cgColor.flatMap { colorToHex($0) }
                )
            }
    }

    // MARK: - Private

    /// notesからUUIDを抽出する
    private func extractUUID(from notes: String) -> UUID? {
        guard let prefixRange = notes.range(of: Constants.eventMarkerPrefix),
              let suffixRange = notes.range(of: Constants.eventMarkerSuffix) else {
            return nil
        }
        let uuidStart = prefixRange.upperBound
        let uuidEnd   = suffixRange.lowerBound
        guard uuidStart < uuidEnd else { return nil }
        let uuidString = String(notes[uuidStart..<uuidEnd]).trimmingCharacters(in: .whitespaces)
        return UUID(uuidString: uuidString)
    }

    /// CGColorを16進数文字列に変換する（ウィジェット表示用）
    private func colorToHex(_ cgColor: CGColor) -> String? {
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
