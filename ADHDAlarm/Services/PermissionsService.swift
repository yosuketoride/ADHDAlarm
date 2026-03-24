import Foundation
import EventKit
import AlarmKit
import Speech
import AVFoundation
import Observation

/// Calendar / AlarmKit / Speech / Microphone の4権限を一括管理する
@Observable
final class PermissionsService {

    // MARK: - 状態

    var isCalendarAuthorized  = false
    var isAlarmKitAuthorized  = false
    var isSpeechAuthorized    = false
    var isMicrophoneAuthorized = false

    /// 4権限すべて許可済みかどうか
    var isAllAuthorized: Bool {
        isCalendarAuthorized && isAlarmKitAuthorized && isSpeechAuthorized && isMicrophoneAuthorized
    }

    /// 少なくとも1つの権限が明示的に拒否されているか（設定アプリへの誘導が必要）
    var hasDeniedPermissions: Bool {
        let calStatus    = EKEventStore.authorizationStatus(for: .event)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus    = AVAudioApplication.shared.recordPermission
        return calStatus    == .denied || calStatus    == .restricted
            || speechStatus == .denied || speechStatus == .restricted
            || micStatus    == .denied
    }

    private let eventStore = EKEventStore()

    // MARK: - 初期化（起動時に現在の状態を反映）

    init() {
        refreshStatuses()
    }

    // MARK: - 権限リクエスト

    /// 4権限を順番にリクエストする（オンボーディングのCTAステップで呼ぶ）
    func requestAll() async {
        await requestCalendar()
        await requestAlarmKit()
        await requestSpeech()
        await requestMicrophone()
    }

    /// カレンダー権限のみリクエスト
    func requestCalendar() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isCalendarAuthorized = granted
        } catch {
            isCalendarAuthorized = false
        }
    }

    /// AlarmKit権限のみリクエスト
    func requestAlarmKit() async {
        do {
            try await AlarmManager.shared.requestAuthorization()
            let state = AlarmManager.shared.authorizationState
            isAlarmKitAuthorized = (state == .authorized)
        } catch {
            isAlarmKitAuthorized = false
        }
    }

    /// 音声認識権限のみリクエスト
    func requestSpeech() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        isSpeechAuthorized = (status == .authorized)
    }

    /// マイク権限のみリクエスト
    func requestMicrophone() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        isMicrophoneAuthorized = granted
    }

    // MARK: - 状態リフレッシュ

    /// アプリ起動時・フォアグラウンド復帰時に現在の権限状態を同期する
    func refreshStatuses() {
        // カレンダー
        let calStatus = EKEventStore.authorizationStatus(for: .event)
        isCalendarAuthorized = (calStatus == .fullAccess || calStatus == .authorized)

        // AlarmKit
        let alarmState = AlarmManager.shared.authorizationState
        isAlarmKitAuthorized = (alarmState == .authorized)

        // 音声認識
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        isSpeechAuthorized = (speechStatus == .authorized)

        // マイク
        let micStatus = AVAudioApplication.shared.recordPermission
        isMicrophoneAuthorized = (micStatus == .granted)
    }
}
