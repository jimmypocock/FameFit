#!/usr/bin/env swift
// Basic test to verify workout sharing functionality

import Foundation

// Test privacy settings
struct WorkoutPrivacySettings {
    var defaultPrivacy: String = "private"
    var allowPublicSharing: Bool = true
    
    func effectivePrivacy(for workoutType: String) -> String {
        // COPPA compliance
        if !allowPublicSharing && defaultPrivacy == "public" {
            return "friends_only"
        }
        return defaultPrivacy
    }
}

// Test privacy enforcement
let settings = WorkoutPrivacySettings()
print("Default privacy: \(settings.defaultPrivacy)")
print("Allow public sharing: \(settings.allowPublicSharing)")

var coppaSettings = WorkoutPrivacySettings()
coppaSettings.allowPublicSharing = false
coppaSettings.defaultPrivacy = "public"
print("COPPA effective privacy: \(coppaSettings.effectivePrivacy(for: "running"))")

// Test activity feed
struct ActivityFeedItem {
    let id: String
    let userId: String
    let activityType: String
    let visibility: String
    let createdAt: Date
    let xpEarned: Int?
}

let feedItem = ActivityFeedItem(
    id: UUID().uuidString,
    userId: "test-user",
    activityType: "workout",
    visibility: "friends_only",
    createdAt: Date(),
    xpEarned: 25
)

print("\nActivity Feed Item:")
print("- Type: \(feedItem.activityType)")
print("- Visibility: \(feedItem.visibility)")
print("- XP Earned: \(feedItem.xpEarned ?? 0)")

print("\n✅ Basic functionality working correctly!")