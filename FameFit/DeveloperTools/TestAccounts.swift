//
//  TestAccounts.swift
//  FameFit
//
//  Test account configuration for development
//  IMPORTANT: This file is only included in DEBUG builds
//

#if DEBUG
import Foundation

/// Test account personas for consistent development testing
enum TestAccountPersona: String, CaseIterable {
    case athlete = "athlete"
    case beginner = "beginner"
    case influencer = "influencer"
    case coach = "coach"
    case casual = "casual"
    
    var displayName: String {
        switch self {
        case .athlete: return "Sarah Chen"
        case .beginner: return "Mike Johnson"
        case .influencer: return "Alex Rivera"
        case .coach: return "Emma Thompson"
        case .casual: return "James Park"
        }
    }
    
    var username: String {
        switch self {
        case .athlete: return "sarah_runner"
        case .beginner: return "mike_fitness"
        case .influencer: return "alex_fit"
        case .coach: return "coach_emma"
        case .casual: return "james_casual"
        }
    }
    
    var bio: String {
        switch self {
        case .athlete:
            return "🏃‍♀️ Marathon runner | 🥇 Boston Qualifier | Chasing that sub-3 hour dream"
        case .beginner:
            return "Just started my fitness journey! 30 days in and feeling great 💪"
        case .influencer:
            return "Certified PT | Helping 10k+ achieve their fitness goals | DM for coaching 📩"
        case .coach:
            return "Former Olympic athlete | Now helping others reach their potential 🏆"
        case .casual:
            return "Weekend warrior | Dad of 2 | Trying to stay healthy"
        }
    }
    
    var workoutCount: Int {
        switch self {
        case .athlete: return 523
        case .beginner: return 28
        case .influencer: return 892
        case .coach: return 1_247
        case .casual: return 145
        }
    }
    
    var totalXP: Int {
        switch self {
        case .athlete: return 125_000
        case .beginner: return 2_800
        case .influencer: return 245_000
        case .coach: return 380_000
        case .casual: return 18_500
        }
    }
    
    var isVerified: Bool {
        switch self {
        case .athlete: return true
        case .beginner: return false
        case .influencer: return true
        case .coach: return true
        case .casual: return false
        }
    }
    
    var joinedDaysAgo: Int {
        switch self {
        case .athlete: return 365
        case .beginner: return 30
        case .influencer: return 730
        case .coach: return 1_095
        case .casual: return 180
        }
    }
}

/// Known test account CloudKit IDs
/// These will be populated after first run with each test Apple ID
struct TestAccountRegistry {
    static let knownAccounts: [TestAccountPersona: String] = [:]
    // These IDs will be populated when you first sign in with each test Apple ID
    // Example: .athlete: "CKRecordID-for-athlete-test-account"
    
    static func persona(for cloudKitID: String) -> TestAccountPersona? {
        knownAccounts.first { $0.value == cloudKitID }?.key
    }
}

/// Test account setup instructions
struct TestAccountSetupGuide {
    static let instructions = """
    FAMEFIT TEST ACCOUNT SETUP
    
    1. Create Apple IDs:
       - famefit.athlete@icloud.com
       - famefit.beginner@icloud.com
       - famefit.influencer@icloud.com
       - famefit.coach@icloud.com
       - famefit.casual@icloud.com
    
    2. Sign into each account on different simulators:
       - Use iPhone 16 Pro for athlete
       - Use iPhone 15 for beginner
       - etc.
    
    3. Run the app and use Developer Menu to:
       - "Register This Account" - saves the CloudKit ID
       - "Setup Persona Data" - creates profile and relationships
    
    4. The CloudKit IDs will be saved to UserDefaults (DEBUG only)
       and automatically loaded on future runs
    """
}
#endif
