import Foundation
@preconcurrency import Supabase

/// 家族リモートスケジュール設定のSupabase実装
final class FamilyRemoteService: FamilyScheduling {

    static let shared = FamilyRemoteService()

    private let client = SupabaseClientFactory.shared
    private(set) var currentDeviceId: String?

    private init() {}

    // MARK: - デバイス登録・認証

    func ensureDeviceRegistered() async throws -> String {
        // SDKに最新セッションを問い合わせる（期限切れなら自動リフレッシュ、なければnil）
        let session: Auth.Session
        if let existing = try? await client.auth.session {
            session = existing
        } else {
            // セッションなし → 新規匿名ログイン
            session = try await client.auth.signInAnonymously()
        }

        let deviceId = session.user.id.uuidString

        // IDが変わった場合のみdevicesテーブルをUPSERT（初回 or セッション再作成時）
        if currentDeviceId != deviceId {
            struct DeviceRow: Encodable {
                let id: String
                let updated_at: String
            }
            try await client
                .from("devices")
                .upsert(DeviceRow(
                    id: deviceId,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                ))
                .execute()
            currentDeviceId = deviceId
        }

        return deviceId
    }

    func updateDeviceToken(_ token: String) async throws {
        guard let deviceId = currentDeviceId else { return }

        struct TokenUpdate: Encodable {
            let id: String
            let device_token: String
            let updated_at: String
        }
        try await client
            .from("devices")
            .upsert(TokenUpdate(
                id: deviceId,
                device_token: token,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .execute()
    }

    // MARK: - 家族ペアリング（親側）

    func generateFamilyCode() async throws -> (linkId: String, code: String) {
        let deviceId = try await ensureDeviceRegistered()
        // 6桁コード（SOS 4桁と区別）
        let code = String(format: "%06d", Int.random(in: 0...999999))
        let linkId = UUID().uuidString
        let expiresAt = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!

        struct LinkRow: Encodable {
            let id: String
            let parent_device_id: String
            let pairing_code: String
            let status: String
            let expires_at: String
        }
        try await client
            .from("family_links")
            .insert(LinkRow(
                id: linkId,
                parent_device_id: deviceId,
                pairing_code: code,
                status: "waiting",
                expires_at: ISO8601DateFormatter().string(from: expiresAt)
            ))
            .execute()

        return (linkId: linkId, code: code)
    }

    func listenToFamilyLinkStatus(linkId: String) -> AsyncStream<String> {
        struct StatusRecord: Decodable { let status: String }

        return AsyncStream { continuation in
            let channel = client.realtime.channel("public:family_links:id=eq.\(linkId)")
            _ = channel.on("postgres_changes", filter: .init(
                event: "UPDATE", schema: "public", table: "family_links",
                filter: "id=eq.\(linkId)"
            )) { message in
                if let record = message.payload["record"] as? [String: Any],
                   let status = record["status"] as? String {
                    continuation.yield(status)
                    if status == "paired" || status == "unpaired" {
                        continuation.finish()
                    }
                }
            }
            Task { await channel.subscribe() }

            // ポーリングによるフォールバック
            let pollingTask = Task {
                for _ in 0..<200 {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { break }
                    let records: [StatusRecord]? = try? await client
                        .from("family_links")
                        .select("status")
                        .eq("id", value: linkId)
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

    func unlinkFamily(linkId: String) async throws {
        try await client
            .from("family_links")
            .update(["status": "unpaired"])
            .eq("id", value: linkId)
            .execute()
    }

    // MARK: - 家族ペアリング（子側）

    func joinFamily(code: String) async throws -> String {
        let deviceId = try await ensureDeviceRegistered()

        struct LinkRecord: Decodable { let id: String }
        let records: [LinkRecord] = try await client
            .from("family_links")
            .select("id")
            .eq("pairing_code", value: code)
            .eq("status", value: "waiting")
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .limit(1)
            .execute()
            .value

        guard let link = records.first else {
            throw FamilyError.invalidCode
        }

        // child_device_idを自分のIDで更新してpaired状態にする
        try await client
            .from("family_links")
            .update(["child_device_id": deviceId, "status": "paired"])
            .eq("id", value: link.id)
            .execute()

        return link.id
    }

    // MARK: - リモート予定（子側）

    func createRemoteEvent(_ event: RemoteEventPayload) async throws {
        let deviceId = try await ensureDeviceRegistered()

        // 送信先（親）のdevice_idをfamily_linksから取得
        struct LinkRecord: Decodable {
            let parent_device_id: String
        }
        let links: [LinkRecord] = try await client
            .from("family_links")
            .select("parent_device_id")
            .eq("id", value: event.familyLinkId)
            .eq("status", value: "paired")
            .limit(1)
            .execute()
            .value

        guard let link = links.first else {
            throw FamilyError.notPaired
        }

        struct EventRow: Encodable {
            let family_link_id: String
            let creator_device_id: String
            let target_device_id: String
            let title: String
            let fire_date: String
            let pre_notification_minutes: Int
            let voice_character: String
            let note: String?
        }
        let formatter = ISO8601DateFormatter()
        try await client
            .from("remote_events")
            .insert(EventRow(
                family_link_id: event.familyLinkId,
                creator_device_id: deviceId,
                target_device_id: link.parent_device_id,
                title: event.title,
                fire_date: formatter.string(from: event.fireDate),
                pre_notification_minutes: event.preNotificationMinutes,
                voice_character: event.voiceCharacter,
                note: event.note
            ))
            .execute()
    }

    func cancelRemoteEvent(id: String) async throws {
        try await client
            .from("remote_events")
            .update(["status": "cancelled"])
            .eq("id", value: id)
            .execute()
    }

    func fetchSentEvents(linkId: String) async throws -> [RemoteEventRecord] {
        let deviceId = try await ensureDeviceRegistered()
        return try await client
            .from("remote_events")
            .select()
            .eq("creator_device_id", value: deviceId)
            .eq("family_link_id", value: linkId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - リモート予定（親側）

    func fetchPendingEvents() async throws -> [RemoteEventRecord] {
        let deviceId = try await ensureDeviceRegistered()
        return try await client
            .from("remote_events")
            .select()
            .eq("target_device_id", value: deviceId)
            .eq("status", value: "pending")
            .order("fire_date", ascending: true)
            .execute()
            .value
    }

    func fetchCancelledEvents() async throws -> [RemoteEventRecord] {
        let deviceId = try await ensureDeviceRegistered()
        return try await client
            .from("remote_events")
            .select()
            .eq("target_device_id", value: deviceId)
            .eq("status", value: "cancelled")
            .execute()
            .value
    }

    func markEventSynced(id: String) async throws {
        try await client
            .from("remote_events")
            .update(["status": "synced", "synced_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()
    }

    func markEventRolledBack(id: String) async throws {
        try await client
            .from("remote_events")
            .update(["status": "rolled_back"])
            .eq("id", value: id)
            .execute()
    }

    func listenToNewEvents() -> AsyncStream<RemoteEventRecord> {
        AsyncStream { continuation in
            guard let deviceId = currentDeviceId else {
                continuation.finish()
                return
            }
            let channel = client.realtime.channel("public:remote_events:target=\(deviceId)")
            _ = channel.on("postgres_changes", filter: .init(
                event: "INSERT", schema: "public", table: "remote_events",
                filter: "target_device_id=eq.\(deviceId)"
            )) { message in
                if let record = message.payload["record"] as? [String: Any],
                   let jsonData = try? JSONSerialization.data(withJSONObject: record),
                   let event = try? JSONDecoder().decode(RemoteEventRecord.self, from: jsonData) {
                    continuation.yield(event)
                }
            }
            Task { await channel.subscribe() }
            continuation.onTermination = { @Sendable _ in
                Task { await channel.unsubscribe() }
            }
        }
    }

    func fetchMyFamilyLinks() async throws -> [FamilyLinkRecord] {
        let deviceId = try await ensureDeviceRegistered()
        return try await client
            .from("family_links")
            .select()
            .or("parent_device_id.eq.\(deviceId),child_device_id.eq.\(deviceId)")
            .eq("status", value: "paired")
            .execute()
            .value
    }

}

// MARK: - エラー定義

enum FamilyError: LocalizedError {
    case invalidCode
    case notPaired
    case deviceNotRegistered

    var errorDescription: String? {
        switch self {
        case .invalidCode:        return "コードが正しくないか、有効期限が切れています。"
        case .notPaired:          return "ペアリングが完了していません。"
        case .deviceNotRegistered: return "デバイス登録が完了していません。"
        }
    }
}
