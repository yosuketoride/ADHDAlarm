import Foundation
import Observation

enum SOSPairingState: Equatable {
    case idle
    case generating
    case waitingForFamily
    case paired
    case error(String)
}

enum SOSTestSendStatus: Equatable {
    case idle
    case sending
    case sent
    case failed(String)
}

@Observable
@MainActor
final class SOSPairingViewModel {
    var state: SOSPairingState = .idle
    var pairingCode: String?
    var timeRemaining: Int = 600
    var testSendStatus: SOSTestSendStatus = .idle
    
    private let sosService: SOSNotifying
    private var countdownTimer: Timer?
    private var pairingTask: Task<Void, Never>?
    
    // アプリ全体のステートにアクセスしてペアリングIDを保存/削除するため
    nonisolated private let appState: AppState
    
    init(sosService: SOSNotifying = SupabaseSOSService(), appState: AppState) {
        self.sosService = sosService
        self.appState = appState
        
        // 既にペアリング設定がある場合は状態を復元
        if appState.sosPairingId != nil {
            self.state = .paired
        }
    }
    
    func startPairing() {
        guard state != .paired else { return }
        
        state = .generating
        pairingTask?.cancel()
        countdownTimer?.invalidate()
        
        pairingTask = Task {
            do {
                let result = try await sosService.generatePairingCode()
                self.pairingCode = result.code
                self.timeRemaining = 600
                self.state = .waitingForFamily
                
                self.startCountdown()
                self.listenStatus(pairingId: result.pairingId)
                
            } catch {
                self.state = .error("通信エラーが発生しました。時間をおいて再試行してください。")
            }
        }
    }
    
    private func startCountdown() {
        // レビュー指摘 #2: Timer/Task.sleepの引き算はバックグラウンドでサスペンドするため
        // 目標時刻から逆算する方式に変更。バックグラウンドから戻っても正確な残り時間を表示する。
        let expireDate = Date().addingTimeInterval(Double(timeRemaining))
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let remaining = max(0, Int(expireDate.timeIntervalSinceNow))
                self.timeRemaining = remaining
                if remaining == 0 {
                    self.countdownTimer?.invalidate()
                    if self.state == .waitingForFamily {
                        self.state = .error("コードの有効期限（10分）が切れました。再発行してください。")
                    }
                }
            }
        }
    }
    
    private func listenStatus(pairingId: String) {
        Task {
            for await status in sosService.listenToPairingStatus(id: pairingId) {
                if status == "paired" {
                    self.state = .paired
                    self.appState.sosPairingId = pairingId
                    self.countdownTimer?.invalidate()
                    break
                }
            }
        }
    }
    
    func cancelPairing() {
        pairingTask?.cancel()
        countdownTimer?.invalidate()
        if appState.sosPairingId == nil {
            state = .idle
        } else {
            state = .paired
        }
    }
    
    func unpair() {
        guard let id = appState.sosPairingId else { return }
        
        pairingTask?.cancel()
        countdownTimer?.invalidate()
        
        Task {
            do {
                try await sosService.unpair(id: id)
                self.appState.sosPairingId = nil
                self.state = .idle
                self.pairingCode = nil
            } catch {
                self.state = .error("連携解除に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - テスト送信

    /// 連携が正しく動いているか確認するためのテストメッセージを送る
    func sendTestMessage() {
        guard let id = appState.sosPairingId else { return }
        testSendStatus = .sending
        Task {
            do {
                try await sosService.sendSOS(pairingId: id, alarmTitle: "LINE連携テスト", minutes: 0)
                self.testSendStatus = .sent
                try? await Task.sleep(for: .seconds(4))
                self.testSendStatus = .idle
            } catch {
                self.testSendStatus = .failed("送信に失敗しました")
            }
        }
    }

    var timeRemainingFormatted: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
