import Foundation

// MARK: - 子→親への予定送信ペイロード

struct RemoteEventPayload: Encodable {
    let familyLinkId: String
    let title: String
    let fireDate: Date
    let preNotificationMinutes: Int
    let voiceCharacter: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case familyLinkId        = "family_link_id"
        case title
        case fireDate            = "fire_date"
        case preNotificationMinutes = "pre_notification_minutes"
        case voiceCharacter      = "voice_character"
        case note
    }
}

// MARK: - DBから取得するリモート予定レコード

struct RemoteEventRecord: Decodable, Identifiable, Sendable {
    let id: String
    let familyLinkId: String
    let creatorDeviceId: String
    let targetDeviceId: String
    let title: String
    let fireDate: Date
    let preNotificationMinutes: Int
    let voiceCharacter: String
    let note: String?
    let status: String
    let createdAt: Date
    let syncedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case familyLinkId        = "family_link_id"
        case creatorDeviceId     = "creator_device_id"
        case targetDeviceId      = "target_device_id"
        case title
        case fireDate            = "fire_date"
        case preNotificationMinutes = "pre_notification_minutes"
        case voiceCharacter      = "voice_character"
        case note
        case status
        case createdAt           = "created_at"
        case syncedAt            = "synced_at"
    }
}

// MARK: - 家族リンクレコード

struct FamilyLinkRecord: Decodable, Identifiable, Sendable {
    let id: String
    let parentDeviceId: String
    let childDeviceId: String?
    let displayName: String?
    let status: String
    let expiresAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case parentDeviceId = "parent_device_id"
        case childDeviceId  = "child_device_id"
        case displayName    = "display_name"
        case status
        case expiresAt      = "expires_at"
        case createdAt      = "created_at"
    }

    /// 自分が親かどうか
    func isParent(deviceId: String) -> Bool { parentDeviceId == deviceId }
    /// 自分が子かどうか
    func isChild(deviceId: String) -> Bool { childDeviceId == deviceId }
}

// MARK: - テンプレート予定（子が選ぶワンタップ入力）

enum EventTemplate: String, CaseIterable, Identifiable {
    case medicine   = "お薬"
    case garbage    = "ゴミ出し"
    case hospital   = "病院・デイサービス"
    case phone      = "電話してね"
    case custom     = "自由入力"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .medicine:  return "💊"
        case .garbage:   return "🗑️"
        case .hospital:  return "🏥"
        case .phone:     return "📞"
        case .custom:    return "✏️"
        }
    }

    var defaultTitle: String? {
        switch self {
        case .medicine:  return "お薬の時間"
        case .garbage:   return "ゴミ出し"
        case .hospital:  return "病院・デイサービス"
        case .phone:     return "電話してね"
        case .custom:    return nil
        }
    }
}
