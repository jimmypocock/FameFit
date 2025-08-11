//
//  AccountStatus.swift
//  FameFit
//
//  Represents the account verification status for Watch app
//

import Foundation

enum AccountStatus: Equatable {
    case verified(UserProfile)
    case notFound
    case checking
    case offline(cachedProfile: UserProfile?)
    case error(String)
    
    var hasAccount: Bool {
        switch self {
        case .verified, .offline(.some):
            return true
        default:
            return false
        }
    }
    
    var canWorkout: Bool {
        // Always allow workouts, even without account
        return true
    }
    
    var profile: UserProfile? {
        switch self {
        case .verified(let profile):
            return profile
        case .offline(.some(let profile)):
            return profile
        default:
            return nil
        }
    }
    
    var displayMessage: String {
        switch self {
        case .verified:
            return ""
        case .notFound:
            return "Set up your FameFit account on iPhone to earn XP and track progress"
        case .checking:
            return "Checking account status..."
        case .offline(let cached):
            if cached != nil {
                return "Offline mode - Workouts will sync when connected"
            } else {
                return "Can't verify account - Continue offline?"
            }
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isOffline: Bool {
        if case .offline = self {
            return true
        }
        return false
    }
}

// MARK: - Cache Keys
struct AccountCacheKeys {
    static let lastCheckDate = "com.jimmypocock.FameFit.lastAccountCheckDate"
    static let cachedProfileData = "com.jimmypocock.FameFit.cachedProfileData"
    static let allowWorkoutsWithoutAccount = "com.jimmypocock.FameFit.allowWorkoutsWithoutAccount"
    static let accountCheckInterval: TimeInterval = 3 * 24 * 60 * 60 // 3 days
    static let backgroundCheckInterval: TimeInterval = 4 * 60 * 60 // 4 hours
}