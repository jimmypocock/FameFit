//
//  WorkoutPrivacySettings.swift
//  FameFit
//
//  User privacy settings for workout sharing
//

import Foundation
import HealthKit

// NOTE: RelationshipStatus is defined in SocialFollowingServicing.swift
// If you get "ambiguous for type lookup" errors, ensure proper imports

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

// MARK: - Workout Privacy Settings

struct WorkoutPrivacySettings: Codable, Equatable {
    // Default privacy level for new workouts
    var defaultPrivacy: WorkoutPrivacy = .private

    // Per-workout type privacy overrides
    var workoutTypeSettings: [String: WorkoutPrivacy] = [:]

    // General sharing preferences
    var allowDataSharing: Bool = false
    var shareAchievements: Bool = true
    var sharePersonalRecords: Bool = false
    var shareWorkoutPhotos: Bool = false
    var shareLocation: Bool = false

    // Age-related restrictions (COPPA compliance)
    var allowPublicSharing: Bool = true // Set to false for users under 13

    // Notification preferences
    var notifyOnWorkoutLikes: Bool = true
    var notifyOnWorkoutComments: Bool = true
    var notifyOnFollowerWorkouts: Bool = true

    init() {
        // Initialize with privacy-first defaults
        defaultPrivacy = .private
        allowDataSharing = false
        shareAchievements = true
        sharePersonalRecords = false
        shareWorkoutPhotos = false
        shareLocation = false
        allowPublicSharing = true
        notifyOnWorkoutLikes = true
        notifyOnWorkoutComments = true
        notifyOnFollowerWorkouts = true
    }

    // MARK: - Workout Type Specific Settings

    func privacyLevel(for workoutType: HKWorkoutActivityType) -> WorkoutPrivacy {
        let key = workoutType.storageKey
        return workoutTypeSettings[key] ?? defaultPrivacy
    }

    mutating func setPrivacyLevel(_ privacy: WorkoutPrivacy, for workoutType: HKWorkoutActivityType) {
        let key = workoutType.storageKey
        workoutTypeSettings[key] = privacy
    }

    mutating func removePrivacyOverride(for workoutType: HKWorkoutActivityType) {
        let key = workoutType.storageKey
        workoutTypeSettings.removeValue(forKey: key)
    }

    // MARK: - Validation

    var isValid: Bool {
        // Ensure COPPA compliance
        if !allowPublicSharing, defaultPrivacy == .public {
            return false
        }

        // Check workout type settings for COPPA compliance
        for (_, privacy) in workoutTypeSettings {
            if !allowPublicSharing, privacy == .public {
                return false
            }
        }

        return true
    }

    // MARK: - Privacy Enforcement

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
        if !allowPublicSharing, requestedPrivacy == .public {
            return .friendsOnly
        }

        return requestedPrivacy
    }
}

// Extension moved to Shared/Extensions/HKWorkoutActivityType+Extensions.swift
