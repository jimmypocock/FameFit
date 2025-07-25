//
//  FameFitCharacters.swift
//  FameFit
//
//  Character definitions and workout messages
//

import Foundation
import HealthKit

// MARK: - FameFit Characters

enum FameFitCharacter: String, CaseIterable, Codable {
    case chad
    case sierra
    case zen

    var emoji: String {
        switch self {
        case .chad:
            "💪"
        case .sierra:
            "🏃‍♀️"
        case .zen:
            "🧘‍♂️"
        }
    }

    var fullName: String {
        switch self {
        case .chad:
            "Chad Thunderbolt"
        case .sierra:
            "Sierra Summit"
        case .zen:
            "Zen Master"
        }
    }

    var catchphrase: String {
        switch self {
        case .chad:
            "MAXIMUM EFFORT, MAXIMUM GAINS!"
        case .sierra:
            "Peak performance starts with one step!"
        case .zen:
            "Find your flow, embrace the journey."
        }
    }

    func workoutCompletionMessage(followers: Int) -> String {
        switch self {
        case .chad:
            "CRUSHED IT! That workout just earned you \(followers) more XP! 💪"
        case .sierra:
            "Amazing job! You've earned \(followers) XP and you're one step closer to your summit! 🏔️"
        case .zen:
            "Beautiful work. \(followers) XP flows to you like water finding its path. 🌊"
        }
    }

    func achievementMessage(milestone: Int) -> String {
        switch self {
        case .chad:
            "BOOM! \(milestone) XP! You're an absolute BEAST! Time to update that gym selfie! 📸"
        case .sierra:
            "Incredible! \(milestone) XP reached! The view from up here is amazing! 🎯"
        case .zen:
            "A milestone of \(milestone) XP. Like a lotus blooming, your potential unfolds. 🪷"
        }
    }

    static func characterForWorkoutType(_ type: HKWorkoutActivityType) -> FameFitCharacter {
        switch type {
        case .functionalStrengthTraining, .traditionalStrengthTraining, .coreTraining, .crossTraining:
            .chad
        case .running, .walking, .cycling, .elliptical, .stairClimbing, .rowing:
            .sierra
        case .yoga, .pilates, .flexibility, .mindAndBody:
            .zen
        default:
            // For other workout types, return a random character
            FameFitCharacter.allCases.randomElement()!
        }
    }
}
