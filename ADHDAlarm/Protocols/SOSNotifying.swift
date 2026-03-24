import Foundation

/// SOS送信（見守り機能）のためのプロトコル定義
protocol SOSNotifying {
    /// 新しい4桁のペアリングコードとUUIDを発行し、Supabase DBに登録する
    func generatePairingCode() async throws -> (pairingId: String, code: String)
    
    /// 特定のペアリングIDの状態（waiting -> paired等）を監視し、結果を返すStream
    func listenToPairingStatus(id: String) -> AsyncStream<String>
    
    /// ペアリングを解除（無効化）する
    func unpair(id: String) async throws
    
    /// SOS（アラーム放置時のエスカレーション）を送信する
    /// - Parameters:
    ///   - pairingId: 連携済みのペアリングID
    ///   - alarmTitle: アラームのタイトル
    ///   - minutes: 放置された時間（分）
    func sendSOS(pairingId: String, alarmTitle: String, minutes: Int) async throws
}
