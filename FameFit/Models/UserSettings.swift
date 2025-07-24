//
//  UserSettings.swift
//  FameFit
//
//  User privacy and notification settings
//

import Foundation
import CloudKit

// MARK: - Notification Settings

enum NotificationPreference: String, CaseIterable, Codable {
    case all = "all"
    case friendsOnly = "friends"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .all:
            return "Everyone"
        case .friendsOnly:
            return "Friends Only"
        case .none:
            return "None"
        }
    }
}

// MARK: - Content Filter

enum ContentFilterLevel: String, CaseIterable, Codable {
    case strict = "strict"
    case moderate = "moderate"
    case off = "off"
    
    var displayName: String {
        switch self {
        case .strict:
            return "Strict"
        case .moderate:
            return "Moderate"
        case .off:
            return "Off"
        }
    }
    
    var description: String {
        switch self {
        case .strict:
            return "Filters all potentially inappropriate content"
        case .moderate:
            return "Filters only explicit content"
        case .off:
            return "No content filtering"
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
    
    // Default settings for new users
    static func defaultSettings(for userID: String) -> UserSettings {
        return UserSettings(
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
            showOnLeaderboards: true
        )
    }
    
    // Check if a user is blocked
    func isUserBlocked(_ userID: String) -> Bool {
        return blockedUsers.contains(userID)
    }
    
    // Check if a user is muted
    func isUserMuted(_ userID: String) -> Bool {
        return mutedUsers.contains(userID)
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
}

// MARK: - CloudKit Extensions

extension UserSettings {
    init?(from record: CKRecord) {
        guard let userID = record["userID"] as? String else { return nil }
        
        self.userID = userID
        self.emailNotifications = (record["emailNotifications"] as? Int64) == 1
        self.pushNotifications = (record["pushNotifications"] as? Int64) == 1
        
        // Privacy settings
        if let privacyString = record["workoutPrivacy"] as? String,
           let privacy = ProfilePrivacyLevel(rawValue: privacyString) {
            self.workoutPrivacy = privacy
        } else {
            self.workoutPrivacy = .friendsOnly
        }
        
        // Message settings
        if let messageString = record["allowMessages"] as? String,
           let messages = NotificationPreference(rawValue: messageString) {
            self.allowMessages = messages
        } else {
            self.allowMessages = .friendsOnly
        }
        
        // User lists
        self.blockedUsers = Set((record["blockedUsers"] as? [String]) ?? [])
        self.mutedUsers = Set((record["mutedUsers"] as? [String]) ?? [])
        
        // Content filter
        if let filterString = record["contentFilter"] as? String,
           let filter = ContentFilterLevel(rawValue: filterString) {
            self.contentFilter = filter
        } else {
            self.contentFilter = .moderate
        }
        
        // Additional preferences
        self.showWorkoutStats = (record["showWorkoutStats"] as? Int64) != 0
        self.allowFriendRequests = (record["allowFriendRequests"] as? Int64) != 0
        self.showOnLeaderboards = (record["showOnLeaderboards"] as? Int64) != 0
    }
    
    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record: CKRecord
        if let recordID = recordID {
            record = CKRecord(recordType: "UserSettings", recordID: recordID)
        } else {
            record = CKRecord(recordType: "UserSettings")
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
        showOnLeaderboards: Bool? = nil
    ) -> UserSettings {
        return UserSettings(
            userID: self.userID,
            emailNotifications: emailNotifications ?? self.emailNotifications,
            pushNotifications: pushNotifications ?? self.pushNotifications,
            workoutPrivacy: workoutPrivacy ?? self.workoutPrivacy,
            allowMessages: allowMessages ?? self.allowMessages,
            blockedUsers: blockedUsers ?? self.blockedUsers,
            mutedUsers: mutedUsers ?? self.mutedUsers,
            contentFilter: contentFilter ?? self.contentFilter,
            showWorkoutStats: showWorkoutStats ?? self.showWorkoutStats,
            allowFriendRequests: allowFriendRequests ?? self.allowFriendRequests,
            showOnLeaderboards: showOnLeaderboards ?? self.showOnLeaderboards
        )
    }
}

// MARK: - Mock Data

extension UserSettings {
    static let mockSettings = UserSettings(
        userID: "mock-user-1",
        emailNotifications: true,
        pushNotifications: true,
        workoutPrivacy: .publicProfile,
        allowMessages: .all,
        blockedUsers: [],
        mutedUsers: ["annoying-user-1"],
        contentFilter: .moderate,
        showWorkoutStats: true,
        allowFriendRequests: true,
        showOnLeaderboards: true
    )
    
    static let mockPrivateSettings = UserSettings(
        userID: "mock-user-2",
        emailNotifications: false,
        pushNotifications: true,
        workoutPrivacy: .privateProfile,
        allowMessages: .none,
        blockedUsers: ["blocked-user-1", "blocked-user-2"],
        mutedUsers: [],
        contentFilter: .strict,
        showWorkoutStats: false,
        allowFriendRequests: false,
        showOnLeaderboards: false
    )
}