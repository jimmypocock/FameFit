//
//  UserSettings.swift
//  FameFit
//
//  User privacy and notification settings
//

import CloudKit
import Foundation
import HealthKit

// MARK: - Relationship Status (for privacy checks)

enum RelationshipStatus: String, CaseIterable {
    case following
    case notFollowing = "not_following"
    case blocked
    case muted
    case pending
    case mutualFollow = "mutual"
}

// MARK: - Workout Privacy Levels

enum WorkoutPrivacy: String, CaseIterable, Codable {
    case `private`
    case friendsOnly = "friends_only"
    case `public`

    var displayName: String {
        switch self {
        case .private:
            "Private"
        case .friendsOnly:
            "Friends Only"
        case .public:
            "Public"
        }
    }

    var description: String {
        switch self {
        case .private:
            "Only you can see this workout"
        case .friendsOnly:
            "Only people you follow back can see this"
        case .public:
            "Anyone who follows you can see this"
        }
    }

    var icon: String {
        switch self {
        case .private:
            "lock.fill"
        case .friendsOnly:
            "person.2.fill"
        case .public:
            "globe"
        }
    }
}

// MARK: - Notification Settings

enum NotificationPreference: String, CaseIterable, Codable {
    case all
    case friendsOnly = "friends"
    case none

    var displayName: String {
        switch self {
        case .all:
            "Everyone"
        case .friendsOnly:
            "Friends Only"
        case .none:
            "None"
        }
    }
}

// MARK: - Content Filter

enum ContentFilterLevel: String, CaseIterable, Codable {
    case strict
    case moderate
    case off

    var displayName: String {
        switch self {
        case .strict:
            "Strict"
        case .moderate:
            "Moderate"
        case .off:
            "Off"
        }
    }

    var description: String {
        switch self {
        case .strict:
            "Filters all potentially inappropriate content"
        case .moderate:
            "Filters only explicit content"
        case .off:
            "No content filtering"
        }
    }
}

// MARK: - User Settings

struct UserSettings: Codable, Equatable {
    let userID: String
    var emailNotifications: Bool
    var pushNotifications: Bool
    var workoutPrivacy: ProfilePrivacyLevel
    var allowMessages: NotificationPreference
    var blockedUsers: Set<String>
    var mutedUsers: Set<String>
    var contentFilter: ContentFilterLevel

    // Additional preferences
    var showWorkoutStats: Bool
    var allowFriendRequests: Bool
    var showOnLeaderboards: Bool
    
    // Workout Privacy Settings (merged from WorkoutPrivacySettings)
    var defaultWorkoutPrivacy: WorkoutPrivacy
    var workoutTypePrivacyOverrides: [String: WorkoutPrivacy] // Per-workout type privacy
    var allowDataSharing: Bool // Share heart rate, calories, etc.
    var shareAchievements: Bool
    var sharePersonalRecords: Bool
    var shareWorkoutPhotos: Bool
    var shareLocation: Bool
    var allowPublicSharing: Bool // COPPA compliance - false for users under 13
    
    // Workout notification preferences
    var notifyOnWorkoutLikes: Bool
    var notifyOnWorkoutComments: Bool
    var notifyOnFollowerWorkouts: Bool

    // Default settings for new users
    static func defaultSettings(for userID: String) -> UserSettings {
        UserSettings(
            userID: userID,
            emailNotifications: true,
            pushNotifications: true,
            workoutPrivacy: .friendsOnly,
            allowMessages: .friendsOnly,
            blockedUsers: [],
            mutedUsers: [],
            contentFilter: .moderate,
            showWorkoutStats: true,
            allowFriendRequests: true,
            showOnLeaderboards: true,
            defaultWorkoutPrivacy: .friendsOnly,
            workoutTypePrivacyOverrides: [:],
            allowDataSharing: true,
            shareAchievements: true,
            sharePersonalRecords: false,
            shareWorkoutPhotos: false,
            shareLocation: false,
            allowPublicSharing: true,
            notifyOnWorkoutLikes: true,
            notifyOnWorkoutComments: true,
            notifyOnFollowerWorkouts: true
        )
    }

    // Check if a user is blocked
    func isUserBlocked(_ userID: String) -> Bool {
        blockedUsers.contains(userID)
    }

    // Check if a user is muted
    func isUserMuted(_ userID: String) -> Bool {
        mutedUsers.contains(userID)
    }

    // Check if user can receive messages from sender
    func canReceiveMessagesFrom(_ senderID: String, isFriend: Bool) -> Bool {
        if isUserBlocked(senderID) { return false }

        switch allowMessages {
        case .all:
            return true
        case .friendsOnly:
            return isFriend
        case .none:
            return false
        }
    }
    
    // MARK: - Workout Privacy Methods (merged from WorkoutPrivacySettings)
    
    func privacyLevel(for workoutType: HKWorkoutActivityType) -> WorkoutPrivacy {
        let key = String(workoutType.rawValue)
        return workoutTypePrivacyOverrides[key] ?? defaultWorkoutPrivacy
    }
    
    mutating func setPrivacyLevel(_ privacy: WorkoutPrivacy, for workoutType: HKWorkoutActivityType) {
        let key = String(workoutType.rawValue)
        workoutTypePrivacyOverrides[key] = privacy
    }
    
    mutating func removePrivacyOverride(for workoutType: HKWorkoutActivityType) {
        let key = String(workoutType.rawValue)
        workoutTypePrivacyOverrides.removeValue(forKey: key)
    }
    
    func canShare(workoutType: HKWorkoutActivityType, with relationship: RelationshipStatus) -> Bool {
        let privacy = privacyLevel(for: workoutType)
        
        switch privacy {
        case .private:
            return false
        case .friendsOnly:
            return relationship == .mutualFollow
        case .public:
            return allowPublicSharing && (relationship == .following || relationship == .mutualFollow)
        }
    }
    
    func effectivePrivacy(for workoutType: HKWorkoutActivityType) -> WorkoutPrivacy {
        let requestedPrivacy = privacyLevel(for: workoutType)
        
        // Enforce COPPA compliance
        if !allowPublicSharing && requestedPrivacy == .public {
            return .friendsOnly
        }
        
        return requestedPrivacy
    }
    
    var isValidForCOPPA: Bool {
        // Ensure COPPA compliance
        if !allowPublicSharing && defaultWorkoutPrivacy == .public {
            return false
        }
        
        // Check workout type settings for COPPA compliance
        for (_, privacy) in workoutTypePrivacyOverrides {
            if !allowPublicSharing && privacy == .public {
                return false
            }
        }
        
        return true
    }
}

// MARK: - CloudKit Extensions

extension UserSettings {
    init?(from record: CKRecord) {
        guard let userID = record["userID"] as? String else { return nil }

        self.userID = userID
        emailNotifications = (record["emailNotifications"] as? Int64) == 1
        pushNotifications = (record["pushNotifications"] as? Int64) == 1

        // Privacy settings
        if let privacyString = record["workoutPrivacy"] as? String,
           let privacy = ProfilePrivacyLevel(rawValue: privacyString) {
            workoutPrivacy = privacy
        } else {
            workoutPrivacy = .friendsOnly
        }

        // Message settings
        if let messageString = record["allowMessages"] as? String,
           let messages = NotificationPreference(rawValue: messageString) {
            allowMessages = messages
        } else {
            allowMessages = .friendsOnly
        }

        // User lists
        blockedUsers = Set((record["blockedUsers"] as? [String]) ?? [])
        mutedUsers = Set((record["mutedUsers"] as? [String]) ?? [])

        // Content filter
        if let filterString = record["contentFilter"] as? String,
           let filter = ContentFilterLevel(rawValue: filterString) {
            contentFilter = filter
        } else {
            contentFilter = .moderate
        }

        // Additional preferences
        showWorkoutStats = (record["showWorkoutStats"] as? Int64) != 0
        allowFriendRequests = (record["allowFriendRequests"] as? Int64) != 0
        showOnLeaderboards = (record["showOnLeaderboards"] as? Int64) != 0
        
        // Workout privacy settings (merged)
        if let defaultPrivacyString = record["defaultWorkoutPrivacy"] as? String,
           let defaultPrivacy = WorkoutPrivacy(rawValue: defaultPrivacyString) {
            defaultWorkoutPrivacy = defaultPrivacy
        } else {
            defaultWorkoutPrivacy = .friendsOnly
        }
        
        // Workout type privacy overrides
        if let overridesData = record["workoutTypePrivacyOverrides"] as? Data,
           let overrides = try? JSONDecoder().decode([String: WorkoutPrivacy].self, from: overridesData) {
            workoutTypePrivacyOverrides = overrides
        } else {
            workoutTypePrivacyOverrides = [:]
        }
        
        // Sharing preferences
        allowDataSharing = (record["allowDataSharing"] as? Int64) != 0
        shareAchievements = (record["shareAchievements"] as? Int64) != 0
        sharePersonalRecords = (record["sharePersonalRecords"] as? Int64) ?? 0 != 0
        shareWorkoutPhotos = (record["shareWorkoutPhotos"] as? Int64) ?? 0 != 0
        shareLocation = (record["shareLocation"] as? Int64) ?? 0 != 0
        allowPublicSharing = (record["allowPublicSharing"] as? Int64) ?? 1 != 0
        
        // Workout notification preferences
        notifyOnWorkoutLikes = (record["notifyOnWorkoutLikes"] as? Int64) ?? 1 != 0
        notifyOnWorkoutComments = (record["notifyOnWorkoutComments"] as? Int64) ?? 1 != 0
        notifyOnFollowerWorkouts = (record["notifyOnFollowerWorkouts"] as? Int64) ?? 1 != 0
    }

    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record = if let recordID {
            CKRecord(recordType: "UserSettings", recordID: recordID)
        } else {
            CKRecord(recordType: "UserSettings")
        }

        record["userID"] = userID
        record["emailNotifications"] = emailNotifications ? Int64(1) : Int64(0)
        record["pushNotifications"] = pushNotifications ? Int64(1) : Int64(0)
        record["workoutPrivacy"] = workoutPrivacy.rawValue
        record["allowMessages"] = allowMessages.rawValue
        if !blockedUsers.isEmpty {
            record["blockedUsers"] = Array(blockedUsers)
        }
        if !mutedUsers.isEmpty {
            record["mutedUsers"] = Array(mutedUsers)
        }
        record["contentFilter"] = contentFilter.rawValue
        record["showWorkoutStats"] = showWorkoutStats ? Int64(1) : Int64(0)
        record["allowFriendRequests"] = allowFriendRequests ? Int64(1) : Int64(0)
        record["showOnLeaderboards"] = showOnLeaderboards ? Int64(1) : Int64(0)
        
        // Workout privacy settings (merged)
        record["defaultWorkoutPrivacy"] = defaultWorkoutPrivacy.rawValue
        if !workoutTypePrivacyOverrides.isEmpty {
            if let overridesData = try? JSONEncoder().encode(workoutTypePrivacyOverrides) {
                record["workoutTypePrivacyOverrides"] = overridesData
            }
        }
        record["allowDataSharing"] = allowDataSharing ? Int64(1) : Int64(0)
        record["shareAchievements"] = shareAchievements ? Int64(1) : Int64(0)
        record["sharePersonalRecords"] = sharePersonalRecords ? Int64(1) : Int64(0)
        record["shareWorkoutPhotos"] = shareWorkoutPhotos ? Int64(1) : Int64(0)
        record["shareLocation"] = shareLocation ? Int64(1) : Int64(0)
        record["allowPublicSharing"] = allowPublicSharing ? Int64(1) : Int64(0)
        
        // Workout notification preferences
        record["notifyOnWorkoutLikes"] = notifyOnWorkoutLikes ? Int64(1) : Int64(0)
        record["notifyOnWorkoutComments"] = notifyOnWorkoutComments ? Int64(1) : Int64(0)
        record["notifyOnFollowerWorkouts"] = notifyOnFollowerWorkouts ? Int64(1) : Int64(0)

        return record
    }

    // Create a copy with modifications
    func with(
        emailNotifications: Bool? = nil,
        pushNotifications: Bool? = nil,
        workoutPrivacy: ProfilePrivacyLevel? = nil,
        allowMessages: NotificationPreference? = nil,
        blockedUsers: Set<String>? = nil,
        mutedUsers: Set<String>? = nil,
        contentFilter: ContentFilterLevel? = nil,
        showWorkoutStats: Bool? = nil,
        allowFriendRequests: Bool? = nil,
        showOnLeaderboards: Bool? = nil,
        defaultWorkoutPrivacy: WorkoutPrivacy? = nil,
        workoutTypePrivacyOverrides: [String: WorkoutPrivacy]? = nil,
        allowDataSharing: Bool? = nil,
        shareAchievements: Bool? = nil,
        sharePersonalRecords: Bool? = nil,
        shareWorkoutPhotos: Bool? = nil,
        shareLocation: Bool? = nil,
        allowPublicSharing: Bool? = nil,
        notifyOnWorkoutLikes: Bool? = nil,
        notifyOnWorkoutComments: Bool? = nil,
        notifyOnFollowerWorkouts: Bool? = nil
    ) -> UserSettings {
        UserSettings(
            userID: userID,
            emailNotifications: emailNotifications ?? self.emailNotifications,
            pushNotifications: pushNotifications ?? self.pushNotifications,
            workoutPrivacy: workoutPrivacy ?? self.workoutPrivacy,
            allowMessages: allowMessages ?? self.allowMessages,
            blockedUsers: blockedUsers ?? self.blockedUsers,
            mutedUsers: mutedUsers ?? self.mutedUsers,
            contentFilter: contentFilter ?? self.contentFilter,
            showWorkoutStats: showWorkoutStats ?? self.showWorkoutStats,
            allowFriendRequests: allowFriendRequests ?? self.allowFriendRequests,
            showOnLeaderboards: showOnLeaderboards ?? self.showOnLeaderboards,
            defaultWorkoutPrivacy: defaultWorkoutPrivacy ?? self.defaultWorkoutPrivacy,
            workoutTypePrivacyOverrides: workoutTypePrivacyOverrides ?? self.workoutTypePrivacyOverrides,
            allowDataSharing: allowDataSharing ?? self.allowDataSharing,
            shareAchievements: shareAchievements ?? self.shareAchievements,
            sharePersonalRecords: sharePersonalRecords ?? self.sharePersonalRecords,
            shareWorkoutPhotos: shareWorkoutPhotos ?? self.shareWorkoutPhotos,
            shareLocation: shareLocation ?? self.shareLocation,
            allowPublicSharing: allowPublicSharing ?? self.allowPublicSharing,
            notifyOnWorkoutLikes: notifyOnWorkoutLikes ?? self.notifyOnWorkoutLikes,
            notifyOnWorkoutComments: notifyOnWorkoutComments ?? self.notifyOnWorkoutComments,
            notifyOnFollowerWorkouts: notifyOnFollowerWorkouts ?? self.notifyOnFollowerWorkouts
        )
    }
}

// MARK: - Mock Data

extension UserSettings {
    static let mockSettings = UserSettings(
        userID: "mock-user-1",
        emailNotifications: true,
        pushNotifications: true,
        workoutPrivacy: ProfilePrivacyLevel.publicProfile,
        allowMessages: NotificationPreference.all,
        blockedUsers: [],
        mutedUsers: ["annoying-user-1"],
        contentFilter: ContentFilterLevel.moderate,
        showWorkoutStats: true,
        allowFriendRequests: true,
        showOnLeaderboards: true,
        defaultWorkoutPrivacy: WorkoutPrivacy.public,
        workoutTypePrivacyOverrides: [:],
        allowDataSharing: true,
        shareAchievements: true,
        sharePersonalRecords: true,
        shareWorkoutPhotos: true,
        shareLocation: false,
        allowPublicSharing: true,
        notifyOnWorkoutLikes: true,
        notifyOnWorkoutComments: true,
        notifyOnFollowerWorkouts: true
    )

    static let mockPrivateSettings = UserSettings(
        userID: "mock-user-2",
        emailNotifications: false,
        pushNotifications: true,
        workoutPrivacy: ProfilePrivacyLevel.privateProfile,
        allowMessages: NotificationPreference.none,
        blockedUsers: ["blocked-user-1", "blocked-user-2"],
        mutedUsers: [],
        contentFilter: ContentFilterLevel.strict,
        showWorkoutStats: false,
        allowFriendRequests: false,
        showOnLeaderboards: false,
        defaultWorkoutPrivacy: WorkoutPrivacy.private,
        workoutTypePrivacyOverrides: [:],
        allowDataSharing: false,
        shareAchievements: false,
        sharePersonalRecords: false,
        shareWorkoutPhotos: false,
        shareLocation: false,
        allowPublicSharing: false,
        notifyOnWorkoutLikes: false,
        notifyOnWorkoutComments: false,
        notifyOnFollowerWorkouts: false
    )
}
