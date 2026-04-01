import Foundation
@preconcurrency import Supabase

final class SupabaseSOSService: SOSNotifying {
    
    private let client: SupabaseClient
    
    nonisolated init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Constants.Supabase.projectURL)!,
            supabaseKey: Constants.Supabase.anonKey
        )
    }
    
    func generatePairingCode() async throws -> (pairingId: String, code: String) {
        let code = String(format: "%04d", Int.random(in: 0...9999))
        
        let id = UUID().uuidString
        let expiresAt = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        
        struct PairingRecord: Encodable {
            let id: String
            let pairing_code: String
            let status: String
            let expires_at: String
        }
        
        let record = PairingRecord(
            id: id,
            pairing_code: code,
            status: "waiting",
            expires_at: ISO8601DateFormatter().string(from: expiresAt)
        )
        
        try await client
            .from("line_pairings")
            .insert(record)
            .execute()
            
        return (pairingId: id, code: code)
    }
    
    func listenToPairingStatus(id: String) -> AsyncStream<String> {
        struct StatusRecord: Decodable { let status: String }

        return AsyncStream { continuation in
            // Realtimeで監視（メイン手段）
            let channel = client.realtimeV2.channel("public:line_pairings:id=eq.\(id)")
            _ = channel.onPostgresChange(
                UpdateAction.self,
                schema: "public",
                table: "line_pairings",
                filter: "id=eq.\(id)"
            ) { action in
                if let status = action.record["status"]?.stringValue {
                    continuation.yield(status)
                    if status == "paired" || status == "unpaired" {
                        continuation.finish()
                    }
                }
            }
            Task { try? await channel.subscribeWithError() }

            // ポーリングによるフォールバック（Realtimeが届かない場合に3秒ごとDBを直接確認）
            let pollingTask = Task {
                for _ in 0..<200 { // 最大10分
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { break }
                    let records: [StatusRecord]? = try? await client
                        .from("line_pairings")
                        .select("status")
                        .eq("id", value: id)
                        .limit(1)
                        .execute()
                        .value
                    if let status = records?.first?.status,
                       status == "paired" || status == "unpaired" {
                        continuation.yield(status)
                        continuation.finish()
                        break
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                Task { await channel.unsubscribe() }
                pollingTask.cancel()
            }
        }
    }
    
    func unpair(id: String) async throws {
        try await client
            .from("line_pairings")
            .update(["status": "unpaired"])
            .eq("id", value: id)
            .execute()
    }
    
    func sendSOS(pairingId: String, alarmTitle: String, minutes: Int) async throws {
        // Encodableな構造体として定義
        struct SOSPayload: Encodable {
            let pairingId: String
            let alarmTitle: String
            let minutes: Int
        }
        
        let payload = SOSPayload(pairingId: pairingId, alarmTitle: alarmTitle, minutes: minutes)
        
        try await client.functions.invoke(
            "send-sos",
            options: FunctionInvokeOptions(body: payload)
        )
    }
}
