//
//  NotificationMetadata.swift
//  FameFit
//
//  Metadata for different notification types
//

import Foundation

// MARK: - Base Protocol

protocol NotificationMetadata: Codable {
    var type: String { get }
}

// MARK: - Workout Metadata

struct WorkoutNotificationMetadata: NotificationMetadata {
    var type: String { "workout" }
    let workoutId: String?
    let workoutType: String?
    let duration: Int // minutes
    let calories: Int
    let xpEarned: Int
    let distance: Double? // meters
    let averageHeartRate: Int?
}

// MARK: - Social Metadata

struct SocialNotificationMetadata: NotificationMetadata {
    var type: String { "social" }
    let userID: String
    let username: String
    let displayName: String
    let profileImageUrl: String?
    let relationshipType: String? // "follower", "following", "mutual"
    let actionCount: Int? // For batched notifications (e.g., "3 people kudos'd")
}

// MARK: - Achievement Metadata

struct AchievementNotificationMetadata: NotificationMetadata {
    var type: String { "achievement" }
    let achievementId: String
    let achievementName: String
    let achievementDescription: String
    let xpRequired: Int
    let category: String
    let iconEmoji: String
}

// MARK: - Challenge Metadata

struct ChallengeNotificationMetadata: NotificationMetadata {
    var type: String { "challenge" }
    let challengeId: String
    let challengeName: String
    let challengerUserID: String
    let challengerUsername: String
    let challengeType: String // "distance", "duration", "calories", "workouts"
    let targetValue: Int
    let duration: String // "daily", "weekly", "monthly"
    let expiresAt: Date
}

// MARK: - System Metadata

struct SystemNotificationMetadata: NotificationMetadata {
    var type: String { "system" }
    let severity: String // "info", "warning", "critical"
    let actionUrl: String?
    let requiresAction: Bool
}

// MARK: - Type-Erased Container

enum NotificationMetadataContainer: Codable {
    case workout(WorkoutNotificationMetadata)
    case social(SocialNotificationMetadata)
    case achievement(AchievementNotificationMetadata)
    case challenge(ChallengeNotificationMetadata)
    case system(SystemNotificationMetadata)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "workout":
            let metadata = try WorkoutNotificationMetadata(from: decoder)
            self = .workout(metadata)
        case "social":
            let metadata = try SocialNotificationMetadata(from: decoder)
            self = .social(metadata)
        case "achievement":
            let metadata = try AchievementNotificationMetadata(from: decoder)
            self = .achievement(metadata)
        case "challenge":
            let metadata = try ChallengeNotificationMetadata(from: decoder)
            self = .challenge(metadata)
        case "system":
            let metadata = try SystemNotificationMetadata(from: decoder)
            self = .system(metadata)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown metadata type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .workout(let metadata):
            try metadata.encode(to: encoder)
        case .social(let metadata):
            try metadata.encode(to: encoder)
        case .achievement(let metadata):
            try metadata.encode(to: encoder)
        case .challenge(let metadata):
            try metadata.encode(to: encoder)
        case .system(let metadata):
            try metadata.encode(to: encoder)
        }
    }
}

// MARK: - Convenience Extensions

extension NotificationItem {
    var workoutMetadata: WorkoutNotificationMetadata? {
        guard let container = metadata,
              case .workout(let meta) = container else { return nil }
        return meta
    }
    
    var socialMetadata: SocialNotificationMetadata? {
        guard let container = metadata,
              case .social(let meta) = container else { return nil }
        return meta
    }
    
    var achievementMetadata: AchievementNotificationMetadata? {
        guard let container = metadata,
              case .achievement(let meta) = container else { return nil }
        return meta
    }
    
    var challengeMetadata: ChallengeNotificationMetadata? {
        guard let container = metadata,
              case .challenge(let meta) = container else { return nil }
        return meta
    }
    
    var systemMetadata: SystemNotificationMetadata? {
        guard let container = metadata,
              case .system(let meta) = container else { return nil }
        return meta
    }
}