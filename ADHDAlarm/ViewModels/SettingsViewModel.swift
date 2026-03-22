import Foundation
import Observation

/// 設定画面の状態管理
@Observable
final class SettingsViewModel {

    // カレンダー選択肢（PRO機能）
    var availableCalendars: [CalendarInfo] = []

    private let appState: AppState
    private let calendarProvider: CalendarProviding

    init(appState: AppState, calendarProvider: CalendarProviding = AppleCalendarProvider()) {
        self.appState         = appState
        self.calendarProvider = calendarProvider
    }

    // AppStateから直接読み書きするプロパティ
    var voiceCharacter: VoiceCharacter {
        get { appState.voiceCharacter }
        set { appState.voiceCharacter = newValue }
    }

    var preNotificationMinutes: Int {
        get { appState.preNotificationMinutes }
        set { appState.preNotificationMinutes = newValue }
    }

    var selectedCalendarID: String? {
        get { appState.selectedCalendarID }
        set { appState.selectedCalendarID = newValue }
    }

    var isAccessibilityModeEnabled: Bool {
        get { appState.isAccessibilityModeEnabled }
        set { appState.isAccessibilityModeEnabled = newValue }
    }

    var notificationType: NotificationType {
        get { appState.notificationType }
        set { appState.notificationType = newValue }
    }

    var audioOutputMode: AudioOutputMode {
        get { appState.audioOutputMode }
        set { appState.audioOutputMode = newValue }
    }

    var micInputMode: MicInputMode {
        get { appState.micInputMode }
        set { appState.micInputMode = newValue }
    }

    var sosContactPhone: String {
        get { appState.sosContactPhone ?? "" }
        set { appState.sosContactPhone = newValue.isEmpty ? nil : newValue }
    }

    var isPro: Bool { appState.subscriptionTier == .pro }

    // 事前通知の選択肢（分）
    let preNotificationOptions = [1, 5, 10, 15, 30, 60]

    // MARK: - カレンダー一覧取得

    func loadCalendars() async {
        availableCalendars = (try? await calendarProvider.availableCalendars()) ?? []
    }
}
