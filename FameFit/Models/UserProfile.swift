//
//  UserProfile.swift
//  FameFit
//
//  User profile model for social features
//

import Foundation
import CloudKit

// MARK: - Privacy Level

enum ProfilePrivacyLevel: String, CaseIterable, Codable {
    case publicProfile = "public"
    case friendsOnly = "friends"
    case privateProfile = "private"
    
    var displayName: String {
        switch self {
        case .publicProfile:
            return "Public"
        case .friendsOnly:
            return "Friends Only"
        case .privateProfile:
            return "Private"
        }
    }
    
    var description: String {
        switch self {
        case .publicProfile:
            return "Anyone can view your profile and workouts"
        case .friendsOnly:
            return "Only approved friends can view your profile"
        case .privateProfile:
            return "Your profile is hidden from everyone"
        }
    }
}

// MARK: - User Profile

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String // CKRecord.ID as String (for the UserProfiles record)
    let userID: String // Reference to Users record ID
    let username: String
    let displayName: String
    let bio: String
    
    // Cached stats from Users table
    let workoutCount: Int
    let totalXP: Int
    let joinedDate: Date
    
    // Profile-specific fields
    let lastUpdated: Date // For cache invalidation
    let isVerified: Bool
    let privacyLevel: ProfilePrivacyLevel
    
    // Image URLs will be stored as strings after upload
    var profileImageURL: String?
    var headerImageURL: String?
    
    // Computed properties
    var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if !displayName.isEmpty {
            return String(displayName.prefix(2))
        } else {
            return String(username.prefix(2))
        }
    }
    
    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Joined \(formatter.string(from: joinedDate))"
    }
    
    var isActive: Bool {
        // Consider active if updated within 7 days
        return lastUpdated.timeIntervalSinceNow > -7 * 24 * 60 * 60
    }
    
    // Validation
    static func isValidUsername(_ username: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_]{3,30}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: username.utf16.count)
        return regex?.firstMatch(in: username, options: [], range: range) != nil
    }
    
    static func isValidDisplayName(_ name: String) -> Bool {
        return !name.isEmpty && name.count <= 50 && name.trimmingCharacters(in: .whitespacesAndNewlines).count > 0
    }
    
    static func isValidBio(_ bio: String) -> Bool {
        return bio.count <= 500
    }
}

// MARK: - CloudKit Extensions

extension UserProfile {
    init?(from record: CKRecord) {
        guard let userID = record["userID"] as? String,
              let username = record["username"] as? String,
              let displayName = record["displayName"] as? String,
              let bio = record["bio"] as? String,
              let workoutCount = record["workoutCount"] as? Int64,
              let totalXP = record["totalXP"] as? Int64,
              let joinedDate = record["joinedDate"] as? Date,
              let lastUpdated = record["lastUpdated"] as? Date,
              let privacyLevelString = record["privacyLevel"] as? String,
              let privacyLevel = ProfilePrivacyLevel(rawValue: privacyLevelString) else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.userID = userID
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.workoutCount = Int(workoutCount)
        self.totalXP = Int(totalXP)
        self.joinedDate = joinedDate
        self.lastUpdated = lastUpdated
        self.isVerified = (record["isVerified"] as? Int64) == 1
        self.privacyLevel = privacyLevel
        self.profileImageURL = record["profileImageURL"] as? String
        self.headerImageURL = record["headerImageURL"] as? String
    }
    
    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record: CKRecord
        if let recordID = recordID {
            record = CKRecord(recordType: "UserProfiles", recordID: recordID)
        } else {
            record = CKRecord(recordType: "UserProfiles")
        }
        
        record["userID"] = userID
        record["username"] = username.lowercased()
        record["displayName"] = displayName
        record["bio"] = bio
        record["workoutCount"] = Int64(workoutCount)
        record["totalXP"] = Int64(totalXP)
        record["joinedDate"] = joinedDate
        record["lastUpdated"] = lastUpdated
        record["isVerified"] = isVerified ? Int64(1) : Int64(0)
        record["privacyLevel"] = privacyLevel.rawValue
        
        if let profileImageURL = profileImageURL {
            record["profileImageURL"] = profileImageURL
        }
        if let headerImageURL = headerImageURL {
            record["headerImageURL"] = headerImageURL
        }
        
        return record
    }
}

// MARK: - Mock Data

extension UserProfile {
    static let mockProfile = UserProfile(
        id: "mock-profile-1",
        userID: "mock-user-1",
        username: "fitnessfanatic",
        displayName: "Fitness Fanatic",
        bio: "Just a fitness enthusiast on a journey to get stronger every day! 💪",
        workoutCount: 42,
        totalXP: 12500,
        joinedDate: Date().addingTimeInterval(-30 * 24 * 60 * 60), // 30 days ago
        lastUpdated: Date(),
        isVerified: false,
        privacyLevel: .publicProfile,
        profileImageURL: nil,
        headerImageURL: nil
    )
    
    static let mockPrivateProfile = UserProfile(
        id: "mock-profile-2",
        userID: "mock-user-2",
        username: "privateperson",
        displayName: "Private Person",
        bio: "Keeping my fitness journey personal",
        workoutCount: 15,
        totalXP: 3200,
        joinedDate: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 7 days ago
        lastUpdated: Date(),
        isVerified: false,
        privacyLevel: .privateProfile,
        profileImageURL: nil,
        headerImageURL: nil
    )
    
    // Additional mock profiles for testing social features
    static let mockProfiles: [UserProfile] = [
        UserProfile(
            id: "runner-pro",
            userID: "runner-user",
            username: "runnerpromax",
            displayName: "Marathon Master",
            bio: "🏃‍♂️ Running my way to fitness! 26.2 miles at a time.",
            workoutCount: 127,
            totalXP: 45000,
            joinedDate: Date().addingTimeInterval(-90 * 24 * 60 * 60),
            lastUpdated: Date().addingTimeInterval(-2 * 60 * 60), // 2 hours ago
            isVerified: true,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        ),
        UserProfile(
            id: "yoga-zen",
            userID: "yoga-user",
            username: "yogazenmaster",
            displayName: "Zen Yoga Flow",
            bio: "🧘‍♀️ Finding balance through movement. Namaste fit!",
            workoutCount: 89,
            totalXP: 28500,
            joinedDate: Date().addingTimeInterval(-45 * 24 * 60 * 60),
            lastUpdated: Date().addingTimeInterval(-30 * 60), // 30 min ago
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        ),
        UserProfile(
            id: "strength-beast",
            userID: "strength-user",
            username: "strengthbeast",
            displayName: "Iron Lifter",
            bio: "💪 Lifting heavy, dreaming bigger. No pain, no gain!",
            workoutCount: 203,
            totalXP: 67800,
            joinedDate: Date().addingTimeInterval(-120 * 24 * 60 * 60),
            lastUpdated: Date().addingTimeInterval(-4 * 60 * 60), // 4 hours ago
            isVerified: true,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        ),
        UserProfile(
            id: "cycling-pro",
            userID: "cycling-user",
            username: "cyclingpro2024",
            displayName: "Bike Explorer",
            bio: "🚴‍♀️ Exploring the world one pedal at a time!",
            workoutCount: 156,
            totalXP: 52300,
            joinedDate: Date().addingTimeInterval(-60 * 24 * 60 * 60),
            lastUpdated: Date().addingTimeInterval(-24 * 60 * 60), // Yesterday
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        ),
        UserProfile(
            id: "beginner-fit",
            userID: "beginner-user",
            username: "juststarted",
            displayName: "Fitness Newbie",
            bio: "🌟 Just started my fitness journey! Every step counts.",
            workoutCount: 8,
            totalXP: 450,
            joinedDate: Date().addingTimeInterval(-14 * 24 * 60 * 60), // 2 weeks ago
            lastUpdated: Date().addingTimeInterval(-6 * 60 * 60), // 6 hours ago
            isVerified: false,
            privacyLevel: .friendsOnly,
            profileImageURL: nil,
            headerImageURL: nil
        )
    ]
}