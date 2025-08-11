//
//  FameFitMessages.swift
//  FameFit Watch App
//
//  Simplified message provider for Watch app
//

import Foundation
import HealthKit

/// Simplified message system for Watch app
enum FameFitMessages {

    /// Message categories for backwards compatibility
    enum MessageCategory {
        case workoutStart
        case workoutMilestone
        case workoutEnd
        case missedWorkout
        case achievement
        case encouragement
        case roast
        case morningMotivation
        case socialMediaReferences
        case supplementTalk
        case philosophicalNonsense
        case humbleBrags
        case catchphrases
    }

    // Simple message arrays for Watch app
    private static let workoutStartMessages = [
        "Let's get this workout started!",
        "Time to crush it!",
        "Here we go, champion!",
        "Ready to earn that XP!",
        "Let's make it count!"
    ]
    
    private static let workoutEndMessages = [
        "Great workout! XP earned!",
        "You crushed it!",
        "Another one in the books!",
        "Workout complete! Well done!",
        "That's how it's done!"
    ]
    
    private static let encouragementMessages = [
        "Keep pushing!",
        "You've got this!",
        "Stay strong!",
        "Almost there!",
        "Don't give up now!"
    ]
    
    /// Get a random message for a category
    static func getMessage(for category: MessageCategory) -> String {
        switch category {
        case .workoutStart:
            return workoutStartMessages.randomElement() ?? "Let's go!"
        case .workoutEnd:
            return workoutEndMessages.randomElement() ?? "Great job!"
        case .encouragement, .workoutMilestone:
            return encouragementMessages.randomElement() ?? "Keep going!"
        default:
            // For other categories, return generic messages
            return "You're doing great!"
        }
    }

    /// Get time-aware message
    static func getTimeAwareMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<9:
            return "Early morning workout! Impressive!"
        case 9..<12:
            return "Morning workout energy!"
        case 12..<17:
            return "Afternoon session! Stay strong!"
        case 17..<21:
            return "Evening workout! Finish strong!"
        default:
            return "Late night grind! Dedication!"
        }
    }

    /// Get workout-specific message
    static func getWorkoutSpecificMessage(workoutType: String, duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        
        if minutes < 10 {
            return "Quick workout! Every minute counts!"
        } else if minutes < 30 {
            return "Solid \(minutes) minute session!"
        } else if minutes < 60 {
            return "Great \(minutes) minute workout!"
        } else {
            return "Epic \(minutes / 60) hour workout! Amazing!"
        }
    }
}
