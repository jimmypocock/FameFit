//
//  ActivityFeedItem.swift
//  FameFit
//
//  Activity feed item for UI display with user profile data
//

import Foundation

struct ActivityFeedItem: Identifiable, Codable {
    let id: String
    let userID: String
    let userProfile: UserProfile?
    let type: ActivityFeedItemType
    let timestamp: Date
    let content: ActivityFeedContent
    let workoutID: String?
    var kudosCount: Int
    var commentCount: Int
    var hasKudoed: Bool
    var kudosSummary: WorkoutKudosSummary?
    
    // Convenience computed properties
    var userName: String {
        userProfile?.username ?? "Unknown User"
    }
    
    var userXP: Int {
        userProfile?.totalXP ?? 0
    }
    
    var isVerified: Bool {
        userProfile?.isVerified ?? false
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
