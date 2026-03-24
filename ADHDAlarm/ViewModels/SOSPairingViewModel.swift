import Foundation
import Observation

enum SOSPairingState: Equatable {
    case idle
    case generating
    case waitingForFamily
    case paired
    case error(String)
}

@Observable
@MainActor
final class SOSPairingViewModel {
    var state: SOSPairingState = .idle
    var pairingCode: String?
    var timeRemaining: Int = 600
    
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
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
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
    
    var timeRemainingFormatted: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
