//
//  ActivityFeedFilters.swift
//  FameFit
//
//  Filtering options for activity feed
//

import Foundation

struct ActivityFeedFilters {
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