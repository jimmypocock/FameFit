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
    case chad = "chad"
    case sierra = "sierra"
    case zen = "zen"
    
    var emoji: String {
        switch self {
        case .chad:
            return "💪"
        case .sierra:
            return "🏃‍♀️"
        case .zen:
            return "🧘‍♂️"
        }
    }
    
    var fullName: String {
        switch self {
        case .chad:
            return "Chad Thunderbolt"
        case .sierra:
            return "Sierra Summit"
        case .zen:
            return "Zen Master"
        }
    }
    
    var catchphrase: String {
        switch self {
        case .chad:
            return "MAXIMUM EFFORT, MAXIMUM GAINS!"
        case .sierra:
            return "Peak performance starts with one step!"
        case .zen:
            return "Find your flow, embrace the journey."
        }
    }
    
    func workoutCompletionMessage(followers: Int) -> String {
        switch self {
        case .chad:
            return "CRUSHED IT! That workout just earned you \(followers) more XP! 💪"
        case .sierra:
            return "Amazing job! You've earned \(followers) XP and you're one step closer to your summit! 🏔️"
        case .zen:
            return "Beautiful work. \(followers) XP flows to you like water finding its path. 🌊"
        }
    }
    
    func achievementMessage(milestone: Int) -> String {
        switch self {
        case .chad:
            return "BOOM! \(milestone) XP! You're an absolute BEAST! Time to update that gym selfie! 📸"
        case .sierra:
            return "Incredible! \(milestone) XP reached! The view from up here is amazing! 🎯"
        case .zen:
            return "A milestone of \(milestone) XP. Like a lotus blooming, your potential unfolds. 🪷"
        }
    }
    
    static func characterForWorkoutType(_ type: HKWorkoutActivityType) -> FameFitCharacter {
        switch type {
        case .functionalStrengthTraining, .traditionalStrengthTraining, .coreTraining, .crossTraining:
            return .chad
        case .running, .walking, .cycling, .elliptical, .stairClimbing, .rowing:
            return .sierra
        case .yoga, .pilates, .flexibility, .mindAndBody:
            return .zen
        default:
            // For other workout types, return a random character
            return FameFitCharacter.allCases.randomElement()!
        }
    }
}