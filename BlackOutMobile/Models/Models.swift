import Foundation

// MARK: - User

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var username: String
    var email: String
    var avatarUrl: String?
    /// Local profile photo (in-memory); not persisted to backend.
    var avatarImageData: Data?
    let createdAt: Date

    init(id: UUID = UUID(), name: String, username: String, email: String, avatarUrl: String? = nil, avatarImageData: Data? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.username = username
        self.email = email
        self.avatarUrl = avatarUrl
        self.avatarImageData = avatarImageData
        self.createdAt = createdAt
    }
}

// MARK: - Group

struct Group: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdByUserId: UUID
    var isPrivate: Bool
    var cardsPerPeriod: Int
    var periodType: PeriodType
    var periodStart: Date?
    var periodEnd: Date?
    var nextResetAt: Date?
    var voteThreshold: VoteThreshold
    var voteDurationHours: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdByUserId: UUID,
        isPrivate: Bool = true,
        cardsPerPeriod: Int = 1,
        periodType: PeriodType = .month,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        nextResetAt: Date? = nil,
        voteThreshold: VoteThreshold = .majority,
        voteDurationHours: Int = 12,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdByUserId = createdByUserId
        self.isPrivate = isPrivate
        self.cardsPerPeriod = cardsPerPeriod
        self.periodType = periodType
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.nextResetAt = nextResetAt
        self.voteThreshold = voteThreshold
        self.voteDurationHours = voteDurationHours
        self.createdAt = createdAt
    }
}

enum PeriodType: String, Codable, CaseIterable, Hashable {
    case semester = "Semester"
    case month = "Month"
    case custom = "Custom"
}

enum VoteThreshold: String, Codable, Hashable {
    case majority = "Majority"
}

// MARK: - Membership

struct Membership: Identifiable, Codable, Hashable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    var role: MemberRole
    var cardsRemaining: Int
    var lastResetAt: Date?
    var lastPetitionAt: Date?

    init(
        id: UUID = UUID(),
        groupId: UUID,
        userId: UUID,
        role: MemberRole = .member,
        cardsRemaining: Int = 1,
        lastResetAt: Date? = nil,
        lastPetitionAt: Date? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.userId = userId
        self.role = role
        self.cardsRemaining = cardsRemaining
        self.lastResetAt = lastResetAt
        self.lastPetitionAt = lastPetitionAt
    }
}

enum MemberRole: String, Codable, CaseIterable, Hashable {
    case admin = "Admin"
    case member = "Member"
}

// MARK: - Night

struct Night: Identifiable, Codable, Hashable {
    let id: UUID
    let groupId: UUID
    let pulledByUserId: UUID
    let pulledAt: Date
    var status: NightStatus
    let createdAt: Date

    init(
        id: UUID = UUID(),
        groupId: UUID,
        pulledByUserId: UUID,
        pulledAt: Date = Date(),
        status: NightStatus = .active,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.pulledByUserId = pulledByUserId
        self.pulledAt = pulledAt
        self.status = status
        self.createdAt = createdAt
    }
}

enum NightStatus: String, Codable, Hashable {
    case active = "Active"
    case closed = "Closed"
}

// MARK: - Media

struct MediaItem: Identifiable, Codable, Hashable {
    let id: UUID
    let nightId: UUID
    let groupId: UUID
    let uploaderUserId: UUID
    var mediaType: MediaType
    var localImageData: Data?
    var url: String?
    var caption: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        nightId: UUID,
        groupId: UUID,
        uploaderUserId: UUID,
        mediaType: MediaType = .image,
        localImageData: Data? = nil,
        url: String? = nil,
        caption: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.nightId = nightId
        self.groupId = groupId
        self.uploaderUserId = uploaderUserId
        self.mediaType = mediaType
        self.localImageData = localImageData
        self.url = url
        self.caption = caption
        self.createdAt = createdAt
    }
}

enum MediaType: String, Codable, Hashable {
    case image = "Image"
    case video = "Video"
}

// MARK: - VoteCase

struct VoteCase: Identifiable, Codable, Hashable {
    let id: UUID
    let groupId: UUID
    let nightId: UUID?
    var caseType: VoteCaseType
    let targetUserId: UUID
    let initiatedByUserId: UUID
    let opensAt: Date
    let closesAt: Date
    var status: VoteCaseStatus
    var result: VoteResult?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        groupId: UUID,
        nightId: UUID? = nil,
        caseType: VoteCaseType,
        targetUserId: UUID,
        initiatedByUserId: UUID,
        opensAt: Date = Date(),
        closesAt: Date? = nil,
        voteDurationHours: Int = 12,
        status: VoteCaseStatus = .open,
        result: VoteResult? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.nightId = nightId
        self.caseType = caseType
        self.targetUserId = targetUserId
        self.initiatedByUserId = initiatedByUserId
        self.opensAt = opensAt
        self.closesAt = closesAt ?? Calendar.current.date(byAdding: .hour, value: voteDurationHours, to: opensAt)!
        self.status = status
        self.result = result
        self.createdAt = createdAt
    }
}

enum VoteCaseType: String, Codable, Hashable {
    case failure = "Failure"
    case petition = "Petition"
}

enum VoteCaseStatus: String, Codable, Hashable {
    case open = "Open"
    case resolved = "Resolved"
}

enum VoteResult: String, Codable, Hashable {
    case pass = "Pass"
    case fail = "Fail"
}

// MARK: - Vote

struct Vote: Identifiable, Codable, Hashable {
    let id: UUID
    let voteCaseId: UUID
    let voterUserId: UUID
    var value: VoteValue
    let createdAt: Date

    init(
        id: UUID = UUID(),
        voteCaseId: UUID,
        voterUserId: UUID,
        value: VoteValue,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.voteCaseId = voteCaseId
        self.voterUserId = voterUserId
        self.value = value
        self.createdAt = createdAt
    }
}

enum VoteValue: String, Codable, Hashable {
    case yes = "Yes"
    case no = "No"
}

// MARK: - App Notification

struct AppNotification: Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    let recipientUserId: UUID
    let title: String
    let message: String
    let notificationType: NotificationType
    let createdAt: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        groupId: UUID,
        recipientUserId: UUID,
        title: String,
        message: String,
        notificationType: NotificationType,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.groupId = groupId
        self.recipientUserId = recipientUserId
        self.title = title
        self.message = message
        self.notificationType = notificationType
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

enum NotificationType: String, Hashable {
    case cardPulled
    case voteStarted
    case voteResolved
    case petitionStarted
    case petitionResolved
    case periodReset
}

// MARK: - Display Helpers

struct MemberInfo: Identifiable, Hashable {
    var id: UUID { membership.id }
    let user: User
    let membership: Membership
}

struct GroupInfo: Identifiable, Hashable {
    var id: UUID { group.id }
    let group: Group
    let membership: Membership
}
