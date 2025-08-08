//
//  UserProfile.swift
//  FameFit
//
//  User profile model for social features
//

import CloudKit
import Foundation

// MARK: - Privacy Level

enum ProfilePrivacyLevel: String, CaseIterable, Codable {
    case publicProfile = "public"
    case friendsOnly = "friends"
    case privateProfile = "private"

    var displayName: String {
        switch self {
        case .publicProfile:
            "Public"
        case .friendsOnly:
            "Friends Only"
        case .privateProfile:
            "Private"
        }
    }

    var description: String {
        switch self {
        case .publicProfile:
            "Anyone can view your profile and workouts"
        case .friendsOnly:
            "Only approved friends can view your profile"
        case .privateProfile:
            "Your profile is hidden from everyone"
        }
    }
}

// MARK: - User Profile

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String // CKRecord.ID as String (for the UserProfiles record)
    let userID: String // Reference to Users record ID
    let username: String
    let bio: String

    // Cached stats from Users table
    let workoutCount: Int  // TODO: Rename to totalWorkouts for consistency
    let totalXP: Int
    let creationDate: Date

    // Profile-specific fields
    let modificationDate: Date // For cache invalidation
    let isVerified: Bool
    let privacyLevel: ProfilePrivacyLevel

    // Image URLs will be stored as strings after upload
    var profileImageURL: String?
    var headerImageURL: String?
    
    // Count verification metadata
    var countsLastVerified: Date?
    var countsVersion: Int?
    var countsSyncToken: String?

    // Computed properties
    var totalWorkouts: Int {
        // Alias for workoutCount to maintain consistency
        return workoutCount
    }
    
    var initials: String {
        return String(username.prefix(2)).uppercased()
    }

    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Joined \(formatter.string(from: creationDate))"
    }

    var isActive: Bool {
        // Consider active if updated within 7 days
        modificationDate.timeIntervalSinceNow > -7 * 24 * 60 * 60
    }

    // Validation
    static func isValidUsername(_ username: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_]{3,30}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: username.utf16.count)
        return regex?.firstMatch(in: username, options: [], range: range) != nil
    }

    static func isValidBio(_ bio: String) -> Bool {
        bio.count <= 500
    }
}

// MARK: - CloudKit Extensions

extension UserProfile {
    init?(from record: CKRecord) {
        guard let userID = record["userID"] as? String,
              let username = record["username"] as? String,
              let bio = record["bio"] as? String,
              let workoutCount = record["workoutCount"] as? Int64,
              let totalXP = record["totalXP"] as? Int64,
              let privacyLevelString = record["privacyLevel"] as? String,
              let privacyLevel = ProfilePrivacyLevel(rawValue: privacyLevelString)
        else {
            return nil
        }
        
        // Use CloudKit's built-in metadata fields
        let creationDate = record.creationDate ?? Date()
        let modificationDate = record.modificationDate ?? Date()

        id = record.recordID.recordName
        self.userID = userID
        self.username = username
        self.bio = bio
        self.workoutCount = Int(workoutCount)
        self.totalXP = Int(totalXP)
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        isVerified = (record["isVerified"] as? Int64) == 1
        self.privacyLevel = privacyLevel
        profileImageURL = record["profileImageURL"] as? String
        headerImageURL = record["headerImageURL"] as? String
    }

    func toCKRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let record = if let recordID {
            CKRecord(recordType: "UserProfiles", recordID: recordID)
        } else {
            CKRecord(recordType: "UserProfiles")
        }

        record["userID"] = userID
        record["username"] = username.lowercased()
        record["bio"] = bio
        record["workoutCount"] = Int64(workoutCount)
        record["totalXP"] = Int64(totalXP)
        // creationDate and modificationDate are managed by CloudKit automatically
        record["isVerified"] = isVerified ? Int64(1) : Int64(0)
        record["privacyLevel"] = privacyLevel.rawValue

        if let profileImageURL {
            record["profileImageURL"] = profileImageURL
        }
        if let headerImageURL {
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
        bio: "Just a fitness enthusiast on a journey to get stronger every day! 💪",
        workoutCount: 42,
        totalXP: 12_500,
        creationDate: Date().addingTimeInterval(-30 * 24 * 60 * 60), // 30 days ago
        modificationDate: Date(),
        isVerified: false,
        privacyLevel: .publicProfile,
        profileImageURL: nil,
        headerImageURL: nil
    )

    static let mockPrivateProfile = UserProfile(
        id: "mock-profile-2",
        userID: "mock-user-2",
        username: "privateperson",
        bio: "Keeping my fitness journey personal",
        workoutCount: 15,
        totalXP: 3_200,
        creationDate: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 7 days ago
        modificationDate: Date(),
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
            bio: "🏃‍♂️ Running my way to fitness! 26.2 miles at a time.",
            workoutCount: 127,
            totalXP: 45_000,
            creationDate: Date().addingTimeInterval(-90 * 24 * 60 * 60),
            modificationDate: Date().addingTimeInterval(-2 * 60 * 60), // 2 hours ago
            isVerified: true,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        ),
        UserProfile(
            id: "yoga-zen",
            userID: "yoga-user",
            username: "yogazenmaster",
            bio: "🧘‍♀️ Finding balance through movement. Namaste fit!",
            workoutCount: 89,
            totalXP: 28_500,
            creationDate: Date().addingTimeInterval(-45 * 24 * 60 * 60),
            modificationDate: Date().addingTimeInterval(-30 * 60), // 30 min ago
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        ),
        UserProfile(
            id: "strength-beast",
            userID: "strength-user",
            username: "strengthbeast",
            bio: "💪 Lifting heavy, dreaming bigger. No pain, no gain!",
            workoutCount: 203,
            totalXP: 67_800,
            creationDate: Date().addingTimeInterval(-120 * 24 * 60 * 60),
            modificationDate: Date().addingTimeInterval(-4 * 60 * 60), // 4 hours ago
            isVerified: true,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        ),
        UserProfile(
            id: "cycling-pro",
            userID: "cycling-user",
            username: "cyclingpro2024",
            bio: "🚴‍♀️ Exploring the world one pedal at a time!",
            workoutCount: 156,
            totalXP: 52_300,
            creationDate: Date().addingTimeInterval(-60 * 24 * 60 * 60),
            modificationDate: Date().addingTimeInterval(-24 * 60 * 60), // Yesterday
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        ),
        UserProfile(
            id: "beginner-fit",
            userID: "beginner-user",
            username: "juststarted",
            bio: "🌟 Just started my fitness journey! Every step counts.",
            workoutCount: 8,
            totalXP: 450,
            creationDate: Date().addingTimeInterval(-14 * 24 * 60 * 60), // 2 weeks ago
            modificationDate: Date().addingTimeInterval(-6 * 60 * 60), // 6 hours ago
            isVerified: false,
            privacyLevel: .friendsOnly,
            profileImageURL: nil,
            headerImageURL: nil
        )
    ]
}
