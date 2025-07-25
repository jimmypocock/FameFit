//
//  FameFitMessages.swift
//  FameFit Watch App
//
//  Backwards compatibility wrapper for FameFitMessageProvider
//

import Foundation
import HealthKit

/// Backwards compatibility wrapper for the new MessageProviding system
enum FameFitMessages {
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
        let newCategory: FameFit_Watch_App.MessageCategory = switch category {
        case .workoutStart: .workoutStart
        case .workoutMilestone: .workoutMilestone
        case .workoutEnd: .workoutEnd
        case .missedWorkout: .missedWorkout
        case .achievement: .achievement
        case .encouragement: .encouragement
        case .roast: .roast
        case .morningMotivation: .morningMotivation
        case .socialMediaReferences: .socialMediaReferences
        case .supplementTalk: .supplementTalk
        case .philosophicalNonsense: .philosophicalNonsense
        case .humbleBrags: .humbleBrags
        case .catchphrases: .catchphrases
        }

        return provider.getRandomMessage(from: newCategory)
    }

    /// Legacy method for time-aware messages
    static func getTimeAwareMessage() -> String {
        provider.getTimeAwareMessage()
    }

    /// Legacy method for workout-specific messages
    static func getWorkoutSpecificMessage(workoutType: String, duration: TimeInterval) -> String {
        // Convert string to HKWorkoutActivityType (simplified)
        let activityType: HKWorkoutActivityType = switch workoutType.lowercased() {
        case "running", "run":
            .running
        case "cycling", "cycle":
            .cycling
        case "walking", "walk":
            .walking
        case "strength", "weights":
            .traditionalStrengthTraining
        default:
            .other
        }

        let context = MessageContext.workoutEnd(
            workoutType: activityType,
            duration: duration
        )

        return provider.getMessage(for: context)
    }
}
