import CloudKit
import Foundation

enum CloudKitSchema {
    
    enum RecordType {
        static let userProfiles = "UserProfiles"
    }
    
    enum UserProfiles {
        static let displayName = "displayName"
        static let followerCount = "followerCount"
        static let totalWorkouts = "totalWorkouts"
        static let currentStreak = "currentStreak"
        static let joinTimestamp = "joinTimestamp"
        static let lastWorkoutTimestamp = "lastWorkoutTimestamp"
    }
}

extension CKRecord {
    
    convenience init(userWithDisplayName displayName: String) {
        self.init(recordType: CloudKitSchema.RecordType.userProfiles)
        self[CloudKitSchema.UserProfiles.displayName] = displayName
        self[CloudKitSchema.UserProfiles.followerCount] = 0
        self[CloudKitSchema.UserProfiles.totalWorkouts] = 0
        self[CloudKitSchema.UserProfiles.currentStreak] = 0
        self[CloudKitSchema.UserProfiles.joinTimestamp] = Date()
    }
    
    var displayName: String? {
        self[CloudKitSchema.UserProfiles.displayName] as? String
    }
    
    var followerCount: Int {
        self[CloudKitSchema.UserProfiles.followerCount] as? Int ?? 0
    }
    
    var totalWorkouts: Int {
        self[CloudKitSchema.UserProfiles.totalWorkouts] as? Int ?? 0
    }
    
    var currentStreak: Int {
        self[CloudKitSchema.UserProfiles.currentStreak] as? Int ?? 0
    }
    
    var joinTimestamp: Date? {
        self[CloudKitSchema.UserProfiles.joinTimestamp] as? Date
    }
    
    var lastWorkoutTimestamp: Date? {
        self[CloudKitSchema.UserProfiles.lastWorkoutTimestamp] as? Date
    }
    
}