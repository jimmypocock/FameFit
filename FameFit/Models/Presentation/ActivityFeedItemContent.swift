//
//  ActivityFeedItemContent.swift
//  FameFit
//
//  Content model for activity feed items
//

import Foundation

struct ActivityFeedItemContent: Codable {
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
