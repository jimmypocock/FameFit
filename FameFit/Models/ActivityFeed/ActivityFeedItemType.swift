//
//  ActivityFeedItemType.swift
//  FameFit
//
//  Activity feed item types with UI configuration
//

import Foundation
import SwiftUI

enum ActivityFeedItemType: String, Codable {
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