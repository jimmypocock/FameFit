//
//  FeedModels.swift
//  FameFit
//
//  Centralized feed-related models used by ActivityFeedService
//

import Foundation
import SwiftUI

// MARK: - Feed Content
// This is used by ActivityFeedItem in ActivityFeedService.swift

struct FeedContent: Codable {
    let title: String
    let subtitle: String?
    let details: [String: String]
    
    // Convenience initializer
    init(title: String, subtitle: String? = nil, details: [String: String] = [:]) {
        self.title = title
        self.subtitle = subtitle
        self.details = details
    }
    
    // Workout specific
    var workoutType: String? {
        details["workoutType"]
    }
    
    var duration: TimeInterval? {
        if let durationString = details["duration"] {
            return TimeInterval(durationString) ?? 0
        }
        return nil
    }
    
    var calories: Int? {
        if let caloriesString = details["calories"] {
            return Int(caloriesString)
        }
        return nil
    }
    
    var xpEarned: Int? {
        if let xpString = details["xpEarned"] {
            return Int(xpString)
        }
        return nil
    }
    
    // Achievement specific
    var achievementName: String? {
        details["achievementName"]
    }
    
    var achievementDescription: String? {
        details["achievementDescription"]
    }
    
    var achievementIcon: String? {
        details["achievementIcon"]
    }
    
    // Level up specific
    var newLevel: String? {
        details["newLevel"]
    }
    
    var newTitle: String? {
        details["newTitle"]
    }
}

// MARK: - Feed Item Type (for UI display)

enum FeedItemType: String, Codable {
    case workout
    case achievement  
    case levelUp = "level_up"
    case milestone
    case challenge
    case groupWorkout = "group_workout"
    
    var icon: String {
        switch self {
        case .workout: return "figure.run"
        case .achievement: return "trophy.fill"
        case .levelUp: return "arrow.up.circle.fill"
        case .milestone: return "flag.checkered"
        case .challenge: return "target"
        case .groupWorkout: return "person.3.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .workout:
            .blue
        case .achievement:
            .yellow
        case .levelUp:
            .purple
        case .milestone:
            .orange
        case .challenge:
            .green
        case .groupWorkout:
            .cyan
        }
    }
}

// MARK: - Feed Item (for UI display)
// This wraps ActivityFeedItem with user profile data for display

struct FeedItem: Identifiable, Codable {
    let id: String
    let userID: String
    let userProfile: UserProfile?
    let type: FeedItemType
    let timestamp: Date
    let content: FeedContent
    let workoutId: String?
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

// MARK: - Feed Filters

struct FeedFilters {
    var showWorkouts = true
    var showAchievements = true
    var showLevelUps = true
    var showMilestones = true
    var timeRange: TimeRange = .all
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var days: Int? {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }
}