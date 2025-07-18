//
//  FameFitMessages.swift
//  FameFit Watch App
//
//  Backwards compatibility wrapper for FameFitMessageProvider
//

import Foundation
import HealthKit

/// Backwards compatibility wrapper for the new MessageProviding system
struct FameFitMessages {
    private static let provider = FameFitMessageProvider()
    
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
    
    /// Legacy method for getting messages by category
    static func getMessage(for category: MessageCategory) -> String {
        // Convert legacy enum to new enum
        let newCategory: FameFit_Watch_App.MessageCategory
        switch category {
        case .workoutStart: newCategory = .workoutStart
        case .workoutMilestone: newCategory = .workoutMilestone
        case .workoutEnd: newCategory = .workoutEnd
        case .missedWorkout: newCategory = .missedWorkout
        case .achievement: newCategory = .achievement
        case .encouragement: newCategory = .encouragement
        case .roast: newCategory = .roast
        case .morningMotivation: newCategory = .morningMotivation
        case .socialMediaReferences: newCategory = .socialMediaReferences
        case .supplementTalk: newCategory = .supplementTalk
        case .philosophicalNonsense: newCategory = .philosophicalNonsense
        case .humbleBrags: newCategory = .humbleBrags
        case .catchphrases: newCategory = .catchphrases
        }
        
        return provider.getRandomMessage(from: newCategory)
    }
    
    /// Legacy method for time-aware messages
    static func getTimeAwareMessage() -> String {
        return provider.getTimeAwareMessage()
    }
    
    /// Legacy method for workout-specific messages
    static func getWorkoutSpecificMessage(workoutType: String, duration: TimeInterval) -> String {
        // Convert string to HKWorkoutActivityType (simplified)
        let activityType: HKWorkoutActivityType
        switch workoutType.lowercased() {
        case "running", "run":
            activityType = .running
        case "cycling", "cycle":
            activityType = .cycling
        case "walking", "walk":
            activityType = .walking
        case "strength", "weights":
            activityType = .traditionalStrengthTraining
        default:
            activityType = .other
        }
        
        let context = MessageContext.workoutEnd(
            workoutType: activityType,
            duration: duration
        )
        
        return provider.getMessage(for: context)
    }
}