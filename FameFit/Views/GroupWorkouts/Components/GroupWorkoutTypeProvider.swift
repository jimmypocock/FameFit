//
//  GroupWorkoutTypeProvider.swift
//  FameFit
//
//  Centralized workout type information for group workout components
//

import HealthKit
import SwiftUI

enum GroupWorkoutTypeProvider {
    // MARK: - Icons

    static func icon(for workoutType: HKWorkoutActivityType) -> String {
        switch workoutType {
        case .running:
            "figure.run"
        case .cycling:
            "bicycle"
        case .swimming:
            "figure.pool.swim"
        case .walking:
            "figure.walk"
        case .hiking:
            "figure.hiking"
        case .yoga:
            "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            "dumbbell"
        default:
            "figure.mixed.cardio"
        }
    }

    // MARK: - Display Names

    static func displayName(for workoutType: HKWorkoutActivityType) -> String {
        switch workoutType {
        case .running:
            "Running"
        case .walking:
            "Walking"
        case .hiking:
            "Hiking"
        case .cycling:
            "Cycling"
        case .swimming:
            "Swimming"
        case .functionalStrengthTraining:
            "Strength Training"
        case .traditionalStrengthTraining:
            "Weight Training"
        case .yoga:
            "Yoga"
        case .pilates:
            "Pilates"
        case .dance:
            "Dance"
        case .boxing:
            "Boxing"
        case .kickboxing:
            "Kickboxing"
        default:
            "Workout"
        }
    }
}
