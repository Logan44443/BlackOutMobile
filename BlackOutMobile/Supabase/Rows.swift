import Foundation

// MARK: - Database Row Models (Supabase → Decodable)

struct ProfileRow: Codable, Hashable {
    let id: UUID
    var name: String
    var username: String
    var avatarUrl: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GroupRow: Codable, Hashable {
    let id: UUID
    var name: String
    let createdByUserId: UUID
    var isPrivate: Bool
    var cardsPerPeriod: Int
    var periodType: String
    var periodStart: Date?
    var periodEnd: Date?
    var nextResetAt: Date?
    var voteThreshold: String
    var voteDurationHours: Int
    var groupPhotoUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdByUserId = "created_by_user_id"
        case isPrivate = "is_private"
        case cardsPerPeriod = "cards_per_period"
        case periodType = "period_type"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case nextResetAt = "next_reset_at"
        case voteThreshold = "vote_threshold"
        case voteDurationHours = "vote_duration_hours"
        case groupPhotoUrl = "group_photo_url"
        case createdAt = "created_at"
    }

    /// Supabase/Postgres often return DATE columns as "yyyy-MM-dd" strings; default Date decoding expects ISO8601 with time.
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdByUserId = try c.decode(UUID.self, forKey: .createdByUserId)
        isPrivate = try c.decode(Bool.self, forKey: .isPrivate)
        cardsPerPeriod = try c.decode(Int.self, forKey: .cardsPerPeriod)
        periodType = try c.decode(String.self, forKey: .periodType)
        periodStart = Self.decodeOptionalDate(c, key: .periodStart)
        periodEnd = Self.decodeOptionalDate(c, key: .periodEnd)
        nextResetAt = try c.decodeIfPresent(Date.self, forKey: .nextResetAt)
        voteThreshold = try c.decode(String.self, forKey: .voteThreshold)
        voteDurationHours = try c.decode(Int.self, forKey: .voteDurationHours)
        groupPhotoUrl = try c.decodeIfPresent(String.self, forKey: .groupPhotoUrl)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    private static func decodeOptionalDate(_ c: KeyedDecodingContainer<GroupRow.CodingKeys>, key: CodingKeys) -> Date? {
        if let date = try? c.decodeIfPresent(Date.self, forKey: key) { return date }
        guard let s = try? c.decodeIfPresent(String.self, forKey: key), !s.isEmpty else { return nil }
        return dateOnlyFormatter.date(from: s)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(createdByUserId, forKey: .createdByUserId)
        try c.encode(isPrivate, forKey: .isPrivate)
        try c.encode(cardsPerPeriod, forKey: .cardsPerPeriod)
        try c.encode(periodType, forKey: .periodType)
        try c.encodeIfPresent(periodStart, forKey: .periodStart)
        try c.encodeIfPresent(periodEnd, forKey: .periodEnd)
        try c.encodeIfPresent(nextResetAt, forKey: .nextResetAt)
        try c.encode(voteThreshold, forKey: .voteThreshold)
        try c.encode(voteDurationHours, forKey: .voteDurationHours)
        try c.encodeIfPresent(groupPhotoUrl, forKey: .groupPhotoUrl)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

struct MembershipRow: Codable, Hashable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    var role: String
    var cardsRemaining: Int
    var lastResetAt: Date?
    var lastPetitionAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role
        case groupId = "group_id"
        case userId = "user_id"
        case cardsRemaining = "cards_remaining"
        case lastResetAt = "last_reset_at"
        case lastPetitionAt = "last_petition_at"
    }
}

struct NightRow: Codable, Hashable {
    let id: UUID
    let groupId: UUID
    let pulledByUserId: UUID
    let pulledAt: Date
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case groupId = "group_id"
        case pulledByUserId = "pulled_by_user_id"
        case pulledAt = "pulled_at"
        case createdAt = "created_at"
    }
}

struct MediaRow: Codable, Hashable {
    let id: UUID
    let nightId: UUID
    let groupId: UUID
    let uploaderUserId: UUID
    let mediaType: String
    let url: String?
    let caption: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, url, caption
        case nightId = "night_id"
        case groupId = "group_id"
        case uploaderUserId = "uploader_user_id"
        case mediaType = "media_type"
        case createdAt = "created_at"
    }
}

struct VoteCaseRow: Codable, Hashable {
    let id: UUID
    let groupId: UUID
    let nightId: UUID?
    let caseType: String
    let targetUserId: UUID
    let initiatedByUserId: UUID
    let opensAt: Date
    let closesAt: Date
    let status: String
    let result: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status, result
        case groupId = "group_id"
        case nightId = "night_id"
        case caseType = "case_type"
        case targetUserId = "target_user_id"
        case initiatedByUserId = "initiated_by_user_id"
        case opensAt = "opens_at"
        case closesAt = "closes_at"
        case createdAt = "created_at"
    }
}

struct VoteRow: Codable, Hashable {
    let id: UUID
    let voteCaseId: UUID
    let voterUserId: UUID
    let value: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, value
        case voteCaseId = "vote_case_id"
        case voterUserId = "voter_user_id"
        case createdAt = "created_at"
    }
}

struct NotificationRow: Codable, Hashable {
    let id: UUID
    let groupId: UUID
    let recipientUserId: UUID
    let title: String
    let message: String
    let notificationType: String
    let isRead: Bool
    let createdAt: Date
    let inviterUserId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, message
        case groupId = "group_id"
        case recipientUserId = "recipient_user_id"
        case notificationType = "notification_type"
        case isRead = "is_read"
        case createdAt = "created_at"
        case inviterUserId = "inviter_user_id"
    }
}

// MARK: - Profile INSERT (fallback if trigger didn't fire)

struct ProfileInsert: Encodable {
    let id: UUID
    let name: String
    let username: String
}

// MARK: - Shared INSERT Types (Encodable)

/// Used for select("user_id") queries.
struct MemberIdRow: Decodable {
    let userId: UUID
    enum CodingKeys: String, CodingKey { case userId = "user_id" }
}

struct CreateMembershipInsert: Encodable {
    let group_id: UUID
    let user_id: UUID
    let role: String
    let cards_remaining: Int
}

struct NightInsert: Encodable {
    let group_id: UUID
    let pulled_by_user_id: UUID
    let status: String
}

struct MediaInsert: Encodable {
    let night_id: UUID
    let group_id: UUID
    let uploader_user_id: UUID
    let media_type: String
    let url: String
    let caption: String?
}

struct DeviceTokenInsert: Encodable {
    let user_id: UUID
    let token: String
    let platform: String
}

struct NotificationInsert: Encodable {
    let group_id: UUID
    let recipient_user_id: UUID
    let title: String
    let message: String
    let notification_type: String
    var inviter_user_id: UUID? = nil
}

struct VoteCaseInsert: Encodable {
    let group_id: UUID
    let night_id: UUID?
    let case_type: String
    let target_user_id: UUID
    let initiated_by_user_id: UUID
    let closes_at: Date
    let status: String
}

struct VoteInsert: Encodable {
    let vote_case_id: UUID
    let voter_user_id: UUID
    let value: String
}

struct CreateGroupInsert: Encodable {
    let name: String
    let created_by_user_id: UUID
    let group_photo_url: String?

    init(name: String, created_by_user_id: UUID, group_photo_url: String? = nil) {
        self.name = name
        self.created_by_user_id = created_by_user_id
        self.group_photo_url = group_photo_url
    }
}

struct GroupPhotoUpdate: Encodable {
    let group_photo_url: String?
}

// MARK: - UPDATE payloads (Encodable, for .update())

struct ProfileUpdate: Encodable {
    var name: String?
    var username: String?
    var avatar_url: String?
    /// Set to true to include avatar_url in the payload (even if nil, to clear it).
    var includeAvatar: Bool = false
    enum CodingKeys: String, CodingKey { case name, username, avatar_url }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(username, forKey: .username)
        if includeAvatar {
            try c.encodeIfPresent(avatar_url, forKey: .avatar_url)
        }
    }
}

struct GroupSettingsUpdate: Encodable {
    var cards_per_period: Int?
    var period_type: String?
    var period_start: String?
    var period_end: String?
    enum CodingKeys: String, CodingKey {
        case cards_per_period, period_type, period_start, period_end
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(cards_per_period, forKey: .cards_per_period)
        try c.encodeIfPresent(period_type, forKey: .period_type)
        try c.encodeIfPresent(period_start, forKey: .period_start)
        try c.encodeIfPresent(period_end, forKey: .period_end)
    }
}

struct MembershipCardsUpdate: Encodable {
    let cards_remaining: Int
}

struct MembershipResetUpdate: Encodable {
    let cards_remaining: Int
    let last_reset_at: String
    let last_petition_at: Date?
    enum CodingKeys: String, CodingKey {
        case cards_remaining, last_reset_at, last_petition_at
    }
}

struct MembershipLastPetitionUpdate: Encodable {
    let last_petition_at: Date
    enum CodingKeys: String, CodingKey { case last_petition_at }
}

struct NightStatusUpdate: Encodable {
    let status: String
}

struct NotificationReadUpdate: Encodable {
    let is_read: Bool
    enum CodingKeys: String, CodingKey { case is_read }
}
