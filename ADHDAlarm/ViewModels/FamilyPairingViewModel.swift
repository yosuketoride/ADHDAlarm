import Foundation
import Observation

/// 家族ペアリング画面の状態管理（親側・子側の両モードを持つ）
@Observable
@MainActor
final class FamilyPairingViewModel {

    // MARK: - 状態

    enum State: Equatable {
        case idle
        case generating           // コード生成中
        case waitingForFamily(code: String, linkId: String, expiresIn: Int)  // 子の参加待ち
        case joining              // コード入力して参加中
        case linked(linkId: String)  // ペアリング完了
        case error(String)
    }

    var state: State = .idle
    /// 子側: ペアリングコード入力欄
    var inputCode: String = ""
    /// カウントダウン（秒）
    private var secondsRemaining: Int = 600
    private var countdownTask: Task<Void, Never>?
    private var listeningTask: Task<Void, Never>?
    private let service: FamilyScheduling

    init(service: FamilyScheduling = FamilyRemoteService.shared) {
        self.service = service
    }

    // MARK: - 親側: コード生成

    func generateCode() {
        guard case .idle = state else { return }
        state = .generating

        Task {
            do {
                let (linkId, code) = try await service.generateFamilyCode()
                secondsRemaining = 600  // 10分
                state = .waitingForFamily(code: code, linkId: linkId, expiresIn: secondsRemaining)
                startCountdown(linkId: linkId, code: code)
                startListening(linkId: linkId)
            } catch {
                state = .error("コードの生成に失敗しました。もう一度お試しください。")
            }
        }
    }

    func cancelWaiting() {
        countdownTask?.cancel()
        listeningTask?.cancel()
        state = .idle
    }

    // MARK: - 子側: コード入力してペアリング

    func joinWithCode() {
        let code = inputCode.trimmingCharacters(in: .whitespaces)
        guard code.count == 6 else {
            state = .error("6桁のコードを入力してください。")
            return
        }
        state = .joining

        Task {
            do {
                let linkId = try await service.joinFamily(code: code)
                state = .linked(linkId: linkId)
            } catch FamilyError.invalidCode {
                state = .error("コードが正しくないか、有効期限が切れています。")
            } catch {
                state = .error("参加に失敗しました。もう一度お試しください。")
            }
        }
    }

    // MARK: - ペアリング解除

    func unlink(linkId: String) {
        Task {
            try? await service.unlinkFamily(linkId: linkId)
            state = .idle
        }
    }

    // MARK: - Private

    private func startCountdown(linkId: String, code: String) {
        countdownTask?.cancel()
        countdownTask = Task {
            while secondsRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                secondsRemaining -= 1
                if case .waitingForFamily = state {
                    state = .waitingForFamily(code: code, linkId: linkId, expiresIn: secondsRemaining)
                }
            }
            if secondsRemaining == 0 {
                state = .error("コードの有効期限が切れました。もう一度お試しください。")
            }
        }
    }

    private func startListening(linkId: String) {
        listeningTask?.cancel()
        listeningTask = Task {
            for await status in service.listenToFamilyLinkStatus(linkId: linkId) {
                if status == "paired" {
                    countdownTask?.cancel()
                    state = .linked(linkId: linkId)
                    break
                }
            }
        }
    }
}
